defmodule GitGud.RepoStorage do
  @moduledoc """
  Conveniences for storing Git objects and meta objects.
  """

  use Supervisor

  alias Ecto.Multi

  alias GitRekt.Git
  alias GitRekt.GitAgent
  alias GitRekt.WireProtocol.ReceivePack

  alias GitGud.DB
  alias GitGud.Commit
  alias GitGud.Repo

  import Ecto.Changeset, only: [change: 2]
  import Ecto.Query, only: [from: 2]

  @batch_insert_chunk_size 5_000

  @doc """
  Starts a repository storage supervisor as part of a supervision tree.
  """
  @spec start_link(keyword) :: Supervisor.on_start
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, [], opts)
  end

  @doc """
  Starts an agent for the given `repo`.
  """
  @spec start_agent(Repo.t) :: DynamicSupervisor.on_start_child
  def start_agent(%Repo{} = repo) do
    name = {:via, Registry, {GitGud.RepoRegistry, "#{repo.owner.login}/#{repo.name}"}}
    DynamicSupervisor.start_child(GitGud.RepoStorage, %{
      id: GitAgent,
      start: {GitAgent, :start_link, [init_param(repo), [name: name]]}
    })
  end

  @doc """
  Initializes a new Git repository for the given `repo`.
  """
  @spec init(Repo.t, boolean) :: {:ok, Git.repo} | {:error, term}
  def init(%Repo{} = repo, bare?) do
    case Application.get_env(:gitgud, :git_storage, :filesystem) do
      :postgres ->
        {:ok, :noop}
      :filesystem ->
        Git.repository_init(workdir(repo), bare?)
    end
  end

  @doc """
  Returns an initialization parameter for the given `repo`.
  """
  @spec init_param(Repo.t) :: term
  def init_param(%Repo{} = repo), do: repo_load_param(repo, Application.get_env(:gitgud, :git_storage, :filesystem))

  @doc """
  Renames the given `repo`.
  """
  @spec rename(Repo.t, Repo.t) :: {:ok, Path.t} | {:error, term}
  def rename(%Repo{} = repo, %Repo{} = old_repo) do
    case Application.get_env(:gitgud, :git_storage, :filesystem) do
      :postgres ->
        {:ok, :noop}
      :filesystem ->
        old_workdir = workdir(old_repo)
        new_workdir = workdir(repo)
        case File.rename(old_workdir, new_workdir) do
          :ok -> {:ok, new_workdir}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  @doc """
  Removes associated data for the given `repo`.
  """
  @spec cleanup(Repo.t) :: {:ok, [Path.t]} | {:error, term}
  def cleanup(%Repo{} = repo) do
    case Application.get_env(:gitgud, :git_storage, :filesystem) do
      :postgres ->
        {:ok, :noop}
      :filesystem -> File.rm_rf(workdir(repo))
    end
  end

  @doc """
  Writes the given `receive_pack` objects and references to the given `repo`.

  This function is called by `GitGud.SSHServer` and `GitGud.SmartHTTPBackend` on each push command.
  It is responsible for writing objects and references to the underlying Git repository.
  """
  @spec push(Repo.t, ReceivePack.t) :: {:ok, [ReceivePack.cmd], [Git.oid]} | {:error, term}
  def push(%Repo{} = repo, %ReceivePack{cmds: cmds} = receive_pack) do
    with {:ok, objs} <- push_objects(receive_pack, repo.id),
          :ok <- push_meta_objects(objs, repo.id),
          :ok <- push_references(receive_pack),
         {:ok, repo} <- DB.update(change(repo, %{pushed_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)})) do
      if Application.get_application(:gitgud_web),
        do: Phoenix.PubSub.broadcast(GitGud.Web.PubSub, "repo:#{repo.id}", {:push, %{refs: cmds, oids: Map.keys(objs)}}),
      else: :ok
    end
  end

  @doc """
  Returns the absolute path to the Git workdir for the given `repo`.

  The path is a concatenation of the Git root path, `repo.owner.login` and `repo.name`.
  """
  @spec workdir(Repo.t) :: Path.t
  def workdir(%Repo{} = repo) do
    repo = DB.preload(repo, :owner)
    Path.join([Application.fetch_env!(:gitgud, :git_root), repo.owner.login, repo.name])
  end

  #
  # Callbacks
  #

  @impl true
  def init([]) do
    children = [
      {DynamicSupervisor, strategy: :one_for_one, name: GitGud.RepoStorage},
      {Registry, keys: :unique, name: GitGud.RepoRegistry}
    ]
    Supervisor.init(children, strategy: :one_for_one)
  end

  #
  # Helpers
  #

  defp push_objects(receive_pack, repo_id) do
    case Application.get_env(:gitgud, :git_storage, :filesystem) do
      :postgres ->
        objs = resolve_git_objects_postgres(receive_pack, repo_id)
        case DB.transaction(write_git_objects(objs, repo_id), timeout: :infinity) do
          {:ok, _} -> {:ok, objs}
        end
      :filesystem ->
        ReceivePack.apply_pack(receive_pack, :write_dump)
    end
  end

  defp push_meta_objects(objs, repo_id) do
    case DB.transaction(write_git_meta_objects(objs, repo_id), timeout: :infinity) do
      {:ok, _} -> :ok
    end
  end

  defp push_references(receive_pack), do: ReceivePack.apply_cmds(receive_pack)

  defp write_git_objects(objs, repo_id) do
    objs
    |> Enum.map(&map_git_object(&1, repo_id))
    |> Enum.chunk_every(@batch_insert_chunk_size)
    |> Enum.with_index()
    |> Enum.reduce(Multi.new(), &write_git_objects_multi/2)
  end

  defp write_git_meta_objects(objs, repo_id) do
    objs
    |> Enum.map(&map_git_meta_object(&1, repo_id))
    |> Enum.reject(&is_nil/1)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.reduce(Multi.new(), &write_git_meta_objects_multi/2)
  end

  defp write_git_objects_multi({objs, i}, multi) do
    Multi.insert_all(multi, {:chunk, i}, "git_objects", objs, on_conflict: {:replace, [:data]}, conflict_target: [:repo_id, :oid])
  end

  defp write_git_meta_objects_multi({schema, {objs, i}}, multi) do
    Multi.insert_all(multi, {schema, {:chunk, i}}, schema, objs)
  end

  defp write_git_meta_objects_multi({schema, objs}, multi) when length(objs) > @batch_insert_chunk_size do
    objs
    |> Enum.chunk_every(@batch_insert_chunk_size)
    |> Enum.with_index()
    |> Enum.reduce(multi, &write_git_meta_objects_multi({schema, &1}, &2))
  end

  defp write_git_meta_objects_multi({schema, objs}, multi) do
    Multi.insert_all(multi, {schema, :all}, schema, objs)
  end

  defp resolve_git_objects_postgres(receive_pack, repo_id) do
    receive_pack
    |> ReceivePack.resolve_pack()
    |> resolve_remaining_git_delta_objects(repo_id)
  end

  defp resolve_remaining_git_delta_objects({objs, []}, _repo_id), do: objs
  defp resolve_remaining_git_delta_objects({objs, delta_refs}, repo_id) do
    source_oids = Enum.map(delta_refs, &elem(&1, 0))
    source_objs = Map.new(DB.all(from o in "git_objects", where: o.repo_id == ^repo_id and o.oid in ^source_oids, select: {o.oid, {o.type, o.data}}), fn
      {oid, {obj_type, obj_data}} -> {oid, {map_git_object_type(obj_type), obj_data}}
    end)
    {new_objs, []} = ReceivePack.resolve_delta_objects(source_objs, delta_refs)
    Map.merge(objs, new_objs)
  end

  defp map_git_object({oid, {obj_type, obj_data}}, repo_id) do
    %{repo_id: repo_id, oid: oid, type: map_git_object_db_type(obj_type), size: byte_size(obj_data), data: obj_data}
  end

  defp map_git_object_type(1), do: :commit
  defp map_git_object_type(2), do: :tree
  defp map_git_object_type(3), do: :blob
  defp map_git_object_type(4), do: :tag

  defp map_git_object_db_type(:commit), do: 1
  defp map_git_object_db_type(:tree), do: 2
  defp map_git_object_db_type(:blob), do: 3
  defp map_git_object_db_type(:tag), do: 4

  defp map_git_meta_object({oid, {:commit, data}}, repo_id) do
    {Commit, Map.merge(Commit.decode!(data), %{repo_id: repo_id, oid: oid})}
  end

  defp map_git_meta_object(_obj, _repo_id), do: nil

  defp repo_load_param(repo, :filesystem), do: workdir(repo)
  defp repo_load_param(repo, :postgres), do: {:postgres, [repo.id, postgres_url(DB.config())]}

  defp postgres_url(conf) do
    to_string(%URI{
      scheme: "postgresql",
      host: Keyword.get(conf, :hostname),
      port: Keyword.get(conf, :port),
      path: "/#{Keyword.get(conf, :database)}",
      userinfo: Enum.join([Keyword.get(conf, :username, []), Keyword.get(conf, :password, [])], ":")
    })
  end
end
