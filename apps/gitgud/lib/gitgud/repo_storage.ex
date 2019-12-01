defmodule GitGud.RepoStorage do
  @moduledoc """
  Conveniences for storing Git objects and meta objects.
  """

  alias Ecto.Multi

  alias GitRekt.Git
  alias GitRekt.WireProtocol.ReceivePack

  alias GitGud.DB

  alias GitGud.User
  alias GitGud.Repo

  alias GitGud.Issue
  alias GitGud.IssueQuery

  alias GitGud.Commit

  import Ecto.Changeset, only: [change: 2]
  import Ecto.Query, only: [from: 2, select: 3]

  @batch_insert_chunk_size 5_000

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
  @spec push(Repo.t, User.t, ReceivePack.t) :: {:ok, [ReceivePack.cmd], [Git.oid]} | {:error, term}
  def push(%Repo{} = repo, %User{} = user, %ReceivePack{} = receive_pack) do
    DB.transaction(fn ->
      with {:ok, objs} <- push_objects(receive_pack, repo.id),
           {:ok, meta} <- push_meta_objects(objs, repo.id, user.id),
            :ok <- push_references(receive_pack),
           {:ok, repo} <- DB.update(change(repo, %{pushed_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)})),
            :ok <- broadcast_events(repo, meta), do:
        {:ok, Map.keys(objs)}
    end)
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

  defp push_meta_objects(objs, repo_id, user_id) do
    case DB.transaction(write_git_meta_objects(objs, repo_id, user_id), timeout: :infinity) do
      {:ok, multi_results} ->
        {:ok, multi_results}
      {:error, reason} ->
        {:error, reason}
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

  defp write_git_meta_objects(objs, repo_id, user_id) do
    objs
    |> Enum.map(&map_git_meta_object(&1, repo_id))
    |> Enum.reject(&is_nil/1)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.reduce(Multi.new(), &write_git_meta_objects_multi(&1, &2, repo_id, user_id))
  end

  defp write_git_objects_multi({objs, i}, multi) do
    Multi.insert_all(multi, {:chunk, i}, "git_objects", objs, on_conflict: {:replace, [:data]}, conflict_target: [:repo_id, :oid])
  end

  defp write_git_meta_objects_multi({Commit, {commits, i}}, multi, repo_id, user_id) do
    multi
    |> Multi.insert_all({Commit, {:chunk, i}}, Commit, commits)
    |> reference_issues_multi(repo_id, user_id, commits)
  end

  defp write_git_meta_objects_multi({schema, {objs, i}}, multi, _repo_id, _user_id) do
    Multi.insert_all(multi, {schema, {:chunk, i}}, schema, objs)
  end

  defp write_git_meta_objects_multi({schema, objs}, multi, repo_id, user_id) when length(objs) > @batch_insert_chunk_size do
    objs
    |> Enum.chunk_every(@batch_insert_chunk_size)
    |> Enum.with_index()
    |> Enum.reduce(multi, &write_git_meta_objects_multi({schema, &1}, &2, repo_id, user_id))
  end

  defp write_git_meta_objects_multi({Commit, commits}, multi, repo_id, user_id) do
    multi
    |> Multi.insert_all({Commit, :all}, Commit, commits)
    |> reference_issues_multi(repo_id, user_id, commits)
  end

  defp write_git_meta_objects_multi({schema, objs}, multi, _repo_id, _user_id) do
    Multi.insert_all(multi, {schema, :all}, schema, objs)
  end

  defp reference_issues_multi(multi, repo_id, user_id, commits) do
    commits =
      Enum.reduce(commits, %{}, fn commit, acc ->
        refs = Regex.scan(~r/\B#([0-9]+)\b/, commit.message, capture: :all_but_first)
        refs = List.flatten(refs)
        refs = Enum.map(refs, &String.to_integer/1)
        unless Enum.empty?(refs),
          do: Map.put(acc, commit.oid, refs),
        else: acc
      end)

    query = IssueQuery.repo_issues_query(repo_id, Enum.uniq(List.flatten(Map.values(commits))))
    query = select(query, [issue: i], {i.id, i.number})
    Enum.reduce(DB.all(query), multi, fn {id, number}, multi ->
      oid = Enum.find_value(commits, fn {oid, refs} -> number in refs && oid end)
      event = %{type: "commit_reference", commit_hash: Git.oid_fmt(oid), user_id: user_id, repo_id: repo_id, timestamp: NaiveDateTime.utc_now()}
      Multi.update_all(multi, {:issue_reference, id}, from(i in Issue, where: i.id == ^id, select: i), push: [events: event])
    end)
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

  defp broadcast_events(_repo, meta) do
    meta
    |> Enum.filter(fn {{:issue_reference, _issue_id}, _val} -> true
                      {_key, _val} -> false end)
    |> Enum.map(fn {{:issue_reference, _issue_id}, {1, [issue]}} -> issue end)
    |> Enum.each(&Absinthe.Subscription.publish(GitGud.Web.Endpoint, List.last(&1.events), issue_event: &1.id))
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
