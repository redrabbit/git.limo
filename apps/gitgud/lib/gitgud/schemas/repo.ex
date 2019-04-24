defmodule GitGud.Repo do
  @moduledoc """
  Git repository schema and helper functions.

  A `GitGud.Repo` is used to create, update and delete Git repositories.

  Beside providing a set of helpers function used for *CRUD* operation on the
  schema and it's associations, this module is also the entry-point (see
  `load_agent/2`) for interactive with the underlying Git repository.
  """

  use Ecto.Schema

  alias Ecto.Multi

  alias GitRekt.GitAgent
  alias GitRekt.Git
  alias GitRekt.WireProtocol.ReceivePack

  alias GitGud.DB
  alias GitGud.GitCommit

  alias GitGud.User
  alias GitGud.UserQuery
  alias GitGud.Maintainer

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  schema "repositories" do
    belongs_to :owner, User
    field :name, :string
    field :public, :boolean, default: true
    field :description, :string
    field :__agent__, :any, virtual: true
    many_to_many :maintainers, User, join_through: Maintainer, on_replace: :delete, on_delete: :delete_all
    timestamps()
    field :pushed_at, :naive_datetime
  end

  @type t :: %__MODULE__{
    id: pos_integer,
    owner_id: pos_integer,
    owner: User.t,
    name: binary,
    public: boolean,
    description: binary,
    maintainers: [User.t],
    inserted_at: NaiveDateTime.t,
    updated_at: NaiveDateTime.t,
    pushed_at: NaiveDateTime.t,
    __agent__: GitAgent.agent | nil
  }

  @doc """
  Creates a new repository.

  ```elixir
  {:ok, repo, git_handle} = GitGud.Repo.create(
    owner_id: user.id,
    name: "gitgud",
    description: "GitHub clone entirely written in Elixir.",
    public: true
  )
  ```

  This function validates the given `params` using `changeset/2`.
  """
  @spec create(map|keyword, keyword) :: {:ok, t} | {:error, Ecto.Changeset.t | term}
  def create(params, opts \\ []) do
    case create_and_init(changeset(%__MODULE__{}, Map.new(params)), Keyword.get(opts, :bare, true)) do
      {:ok, %{repo: repo, init: handle}} ->
        owner = UserQuery.by_id(repo.owner_id)
        {:ok, struct(repo, owner: owner, maintainers: [owner], __agent__: handle)}
      {:error, :repo, changeset, _changes} ->
        {:error, changeset}
      {:error, :init, reason, _changes} ->
        {:error, reason}
    end
  end

  @doc """
  Similar to `create/2`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec create!(map|keyword, keyword) :: t
  def create!(params, opts \\ []) do
    case create(params, opts) do
      {:ok, repo} -> repo
      {:error, changeset} -> raise Ecto.InvalidChangesetError, action: changeset.action, changeset: changeset
    end
  end

  @doc """
  Updates the given `repo` with the given `params`.

  ```elixir
  {:ok, repo} = GitGud.Repo.update(repo, description: "Host open-source project without hassle.")
  ```

  This function validates the given `params` using `changeset/2`.
  """
  @spec update(t, map|keyword) :: {:ok, t} | {:error, Ecto.Changeset.t | :file.posix}
  def update(%__MODULE__{} = repo, params) do
    case update_and_rename(changeset(repo, Map.new(params))) do
      {:ok, %{repo: repo}} ->
        {:ok, repo}
      {:error, :repo, changeset, _changes} ->
        {:error, changeset}
      {:error, :rename, reason, _changes} ->
        {:error, reason}
    end
  end

  @doc """
  Similar to `update/2`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec update!(t, map|keyword) :: t
  def update!(%__MODULE__{} = repo, params) do
    case update(repo, params) do
      {:ok, repo} -> repo
      {:error, %Ecto.Changeset{} = changeset} ->
        raise Ecto.InvalidChangesetError, action: changeset.action, changeset: changeset
      {:error, reason} ->
        raise File.Error, reason: reason, action: "rename directory", path: IO.chardata_to_string(workdir(repo))
    end
  end

  @doc """
  Deletes the given `repo`.

  Repository associations (maintainers, issues, etc.) and related Git data will automatically be deleted.
  """
  @spec delete(t) :: {:ok, t} | {:error, Ecto.Changeset.t}
  def delete(%__MODULE__{} = repo) do
    case delete_and_cleanup(repo) do
      {:ok, %{repo: repo}} ->
        {:ok, repo}
      {:error, :repo, changeset, _changes} ->
        {:error, changeset}
      {:error, :cleanup, reason, _changes} ->
        {:error, reason}
    end
  end

  @doc """
  Similar to `delete!/1`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec delete!(t) :: t
  def delete!(%__MODULE__{} = repo) do
    case delete(repo) do
      {:ok, repo} -> repo
      {:error, changeset} -> raise Ecto.InvalidChangesetError, action: changeset.action, changeset: changeset
    end
  end

  @doc ~S"""
  Loads the Git agent for the given `repo`.

  Once loaded, an agent can be used to interact with the underlying Git repository:

  ```elixir
  {:ok, repo} = GitGud.Repo.load_agent(repo)
  {:ok, head} = GitRekt.GitAgent.head(repo)
  IO.puts "current branch: #{head.name}"
  ```

  Often times, it might be preferable to manipulate Git objects in a dedicated process.
  For example when you want to access a single repository from multiple processes simultaneously.

  For such cases, you can explicitly tell to load the agent in `:shared` mode.

  In shared mode, `GitRekt.GitAgent` does not operate on the `t:GitRekt.Git.repo/0` pointer directly.
  Instead it starts a dedicated process and executes commands via message passing.
  """
  @spec load_agent(t, :inproc | :shared) :: {:ok, t} | {:error, term}
  def load_agent(repo, mode \\ :inproc)
  def load_agent(%__MODULE__{__agent__: nil} = repo, :inproc) do
    arg = repo_load_param(repo, Application.get_env(:gitgud, :git_storage, :filesystem))
    case Git.repository_load(arg) do
      {:ok, agent} ->
        {:ok, struct(repo, __agent__: agent)}
      {:error, reason} ->
        {:error, reason}
    end
  end

  def load_agent(%__MODULE__{__agent__: nil} = repo, :shared) do
    arg = repo_load_param(repo, Application.get_env(:gitgud, :git_storage, :filesystem))
    case GitAgent.start_link(arg) do
      {:ok, agent} ->
        {:ok, struct(repo, __agent__: agent)}
      {:error, reason} ->
        {:error, reason}
    end
  end

  def load_agent(%__MODULE__{} = repo, _mode), do: repo

  @doc """
  Similar to `load_agent/1`, but raises an exception if an error occurs.
  """
  @spec load_agent!(t) :: t
  def load_agent!(%__MODULE__{} = repo, mode \\ :inproc) do
    case load_agent(repo, mode) do
      {:ok, repo} -> repo
      {:error, reason} -> raise reason
    end
  end

  @doc """
  Returns a repository changeset for the given `params`.
  """
  @spec changeset(t, map) :: Ecto.Changeset.t
  def changeset(%__MODULE__{} = repo, params \\ %{}) do
    repo
    |> cast(params, [:owner_id, :name, :public, :description])
    |> validate_required([:owner_id, :name])
    |> assoc_constraint(:owner)
    |> validate_format(:name, ~r/^[a-zA-Z0-9_-]+$/)
    |> validate_length(:name, min: 3, max: 80)
    |> validate_exclusion(:name, ["settings"])
    |> validate_maintainers()
    |> unique_constraint(:name, name: :repositories_owner_id_name_index)
  end

  @doc """
  Returns the list of associated `GitGud.Maintainer` for the given `repo`.
  """
  @spec maintainers(t) :: [Maintainer.t]
  def maintainers(%__MODULE__{id: repo_id} = _repo) do
    query = from(m in Maintainer,
           join: u in assoc(m, :user),
          where: m.repo_id == ^repo_id,
        preload: [user: u])
    DB.all(query)
  end

  @doc """
  Returns a single `GitGud.Maintainer` for the given `repo` and `user`.
  """
  @spec maintainer(t, User.t) :: Maintainer.t | nil
  def maintainer(%__MODULE__{id: repo_id} = _repo, %User{id: user_id} = user) do
    query = from(m in Maintainer, where: m.repo_id == ^repo_id and m.user_id == ^user_id)
    if maintainer = DB.one(query), do: struct(maintainer, user: user)
  end

  @doc """
  Returns the absolute path to the Git workdir for the given `repo`.

  The path is a concatenation of `root_path/0`, `repo.owner.login` and `repo.name`.
  """
  @spec workdir(t) :: Path.t
  def workdir(%__MODULE__{} = repo) do
    repo = DB.preload(repo, :owner)
    Path.join([root_path(), repo.owner.login, repo.name])
  end

  @doc """
  Returns the absolute path to the Git root directory.
  """
  @spec root_path() :: Path.t | nil
  def root_path() do
    Application.fetch_env!(:gitgud, :git_root)
  end

  @doc """
  Applies the given `receive_pack` to the `repo`.

  This function is called by `GitGud.SSHServer` and `GitGud.SmartHTTPBackend` on each push command.
  It is responsible for writing objects and references to the underlying Git repository.

  See `GitRekt.WireProtocol.ReceivePack` for more details.
  """
  @spec push(t, ReceivePack.t) :: :ok | {:error, term}
  def push(%__MODULE__{} = repo, %ReceivePack{cmds: cmds} = receive_pack) do
    with {:ok, objs} <- write_git_objects(receive_pack, repo.id),
          :ok <- ReceivePack.apply_cmds(receive_pack),
          :ok <- write_git_meta_objects(objs, repo.id),
         {:ok, repo} <- DB.update(change(repo, %{pushed_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)})), do:
      Phoenix.PubSub.broadcast(GitGud.Web.PubSub, "repo:#{repo.id}", {:push, %{refs: cmds, oids: Map.keys(objs)}})
  end

  #
  # Protocols
  #

  defimpl GitGud.AuthorizationPolicies do
    alias GitGud.Repo

    # Owner can do everything
    def can?(%Repo{owner_id: user_id}, %User{id: user_id}, _action), do: true

    # Everybody can read public repos.
    def can?(%Repo{public: true}, _user, :read), do: true

    # Maintainers can perform action if he has granted permission to do so.
    def can?(%Repo{} = repo, %User{} = user, action) do
      if maintainer = Repo.maintainer(repo, user) do
        cond do
          action == :read && maintainer.permission in ["read", "write", "admin"] ->
            true
          action == :write && maintainer.permission in ["write", "admin"] ->
            true
          action == :admin && maintainer.permission == "admin" ->
            true
          true ->
            false
        end
      end
    end

    # Everything-else is forbidden.
    def can?(%Repo{}, _user, _actions), do: false
  end

  #
  # Helpers
  #

  defp repo_load_param(repo, :filesystem), do: workdir(repo)
  defp repo_load_param(repo, :postgres), do: {:postgres, [repo.id, postgres_url(DB.config())]}

  defp write_git_objects(receive_pack, repo_id) do
    if Application.get_env(:gitgud, :git_storage, :filesystem) != :postgres do
      ReceivePack.apply_pack(receive_pack, :write_dump)
    else
      receive_pack
      |> ReceivePack.resolve_pack()
      |> resolve_remaining_git_delta_objects(repo_id)
      |> write_git_objects_batch(repo_id)
    end
  end

  defp write_git_objects_batch(objs, repo_id) do
    objs
    |> Enum.map(&map_git_object(&1, repo_id))
    |> Enum.chunk_every(5000)
    |> Enum.with_index()
    |> Enum.reduce(Multi.new(), fn {objs, i}, multi -> Multi.insert_all(multi, {:chunk, i}, "git_objects", objs, on_conflict: {:replace, [:data]}, conflict_target: [:repo_id, :oid]) end)
    |> DB.transaction()
    {:ok, objs}
  end

  defp write_git_meta_objects(objs, repo_id) do
    objs
    |> Enum.map(&map_git_meta_object(&1, repo_id))
    |> Enum.reject(&is_nil/1)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.each(fn {schema, objs} -> DB.insert_all(schema, objs) end)
  end

  def map_git_object_type(1), do: :commit
  def map_git_object_type(2), do: :tree
  def map_git_object_type(3), do: :blob
  def map_git_object_type(4), do: :tag

  def map_git_object_db_type(:commit), do: 1
  def map_git_object_db_type(:tree), do: 2
  def map_git_object_db_type(:blob), do: 3
  def map_git_object_db_type(:tag), do: 4

  defp map_git_object({oid, {obj_type, obj_data}}, repo_id) do
    %{repo_id: repo_id, oid: oid, type: map_git_object_db_type(obj_type), size: byte_size(obj_data), data: obj_data}
  end

  defp map_git_meta_object({oid, {:commit, data}}, repo_id) do
    {GitCommit, %{repo_id: repo_id, oid: oid, parents: extract_git_commit_parents(data)}}
  end

  defp map_git_meta_object(_obj, _repo_id), do: nil

  defp resolve_remaining_git_delta_objects({objs, []}, _repo_id), do: objs
  defp resolve_remaining_git_delta_objects({objs, delta_refs}, repo_id) do
    source_oids = Enum.map(delta_refs, &elem(&1, 0))
    source_objs = Map.new(DB.all(from o in "git_objects", where: o.repo_id == ^repo_id and o.oid in ^source_oids, select: {o.oid, {o.type, o.data}}), fn
      {oid, {obj_type, obj_data}} -> {oid, {map_git_object_type(obj_type), obj_data}}
    end)
    {new_objs, []} = ReceivePack.resolve_delta_objects(source_objs, delta_refs)
    Map.merge(objs, new_objs)
  end

  defp extract_git_commit(data) do
    [header, message] = String.split(data, "\n\n", parts: 2)
    header
    |> String.split("\n", trim: true)
    |> Enum.chunk_by(&String.starts_with?(&1, " "))
    |> Enum.chunk_every(2)
    |> Enum.flat_map(fn
      [one] ->
        one
      [one, two] ->
        two = Enum.join(Enum.map(two, &String.trim_leading/1), "")
        List.update_at(one, -1, &(&1 <> two))
    end)
    |> Enum.map(fn line ->
      [key, val] = String.split(line, " ", parts: 2)
      {key, String.trim_trailing(val)}
    end)
    |> List.insert_at(0, {"message", message})
  end

  defp extract_git_commit_parents(data) do
    data
    |> extract_git_commit()
    |> Enum.filter(&elem(&1, 0) == "parent")
    |> Enum.map(&Git.oid_parse(elem(&1, 1)))
  end

  defp create_and_init(changeset, bare?) do
    Multi.new()
    |> Multi.insert(:repo, changeset)
    |> Multi.run(:maintainer, &create_maintainer/2)
    |> Multi.run(:init, &init(&1, &2, bare?))
    |> DB.transaction()
  end

  defp create_maintainer(db, %{repo: repo}) do
    changeset = Maintainer.changeset(%Maintainer{}, %{repo_id: repo.id, user_id: repo.owner_id, permission: "admin"})
    db.insert(changeset)
  end

  defp validate_maintainers(changeset) do
    if maintainers = changeset.params["maintainers"],
      do: put_assoc(changeset, :maintainers, maintainers),
    else: changeset
  end

  defp update_and_rename(changeset) do
    Multi.new()
    |> Multi.update(:repo, changeset)
    |> Multi.run(:rename, &rename(&1, &2, changeset))
    |> DB.transaction()
  end

  defp delete_and_cleanup(repo) do
    Multi.new()
    |> Multi.delete(:repo, repo)
    |> Multi.run(:cleanup, &cleanup/2)
    |> DB.transaction()
  end

  defp init(_db, %{repo: repo}, bare?) do
    if Application.get_env(:gitgud, :git_storage, :filesystem) == :filesystem,
      do: Git.repository_init(workdir(repo), bare?),
    else: {:ok, :noop}
  end

  defp rename(_db, %{repo: repo}, changeset) do
    if Application.get_env(:gitgud, :git_storage, :filesystem) == :filesystem,
      do: move_workdir(repo, changeset),
    else: {:ok, :noop}
  end

  defp cleanup(_db, %{repo: repo}) do
    if Application.get_env(:gitgud, :git_storage, :filesystem) == :filesystem,
      do: File.rm_rf(workdir(repo)),
    else: {:ok, :noop}
  end

  defp move_workdir(repo, changeset) do
    old_workdir = workdir(changeset.data)
    if get_change(changeset, :name) do
      new_workdir = workdir(repo)
      case File.rename(old_workdir, new_workdir) do
        :ok -> {:ok, new_workdir}
        {:error, reason} -> {:error, reason}
      end
    else
      {:ok, old_workdir}
    end
  end

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
