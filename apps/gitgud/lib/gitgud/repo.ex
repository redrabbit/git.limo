defmodule GitGud.Repo do
  @moduledoc """
  Repository schema and helper functions.
  """

  use Ecto.Schema

  import Ecto, only: [assoc: 2]
  import Ecto.Changeset

  alias Ecto.Multi

  alias GitRekt.Git

  alias GitGud.DB
  alias GitGud.User
  alias GitGud.UserQuery

  alias GitGud.GitBlob
  alias GitGud.GitCommit
  alias GitGud.GitReference
  alias GitGud.GitTag
  alias GitGud.GitTree

  schema "repositories" do
    belongs_to    :owner,       User
    field         :name,        :string
    field         :public,      :boolean, default: true
    field         :description, :string
    many_to_many  :maintainers, User, join_through: "repositories_maintainers", on_replace: :delete, on_delete: :delete_all
    timestamps()
  end

  @type git_object :: GitBlob.t | GitCommit.t | GitTag.t | GitTree.t

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
  }

  @doc """
  Returns a repository changeset for the given `params`.
  """
  @spec changeset(t, map) :: Ecto.Changeset.t
  def changeset(%__MODULE__{} = repository, params \\ %{}) do
    repository
    |> cast(params, [:owner_id, :name, :public, :description])
    |> validate_required([:owner_id, :name])
    |> validate_format(:name, ~r/^[a-zA-Z0-9_-]+$/)
    |> validate_length(:name, min: 3, max: 80)
    |> assoc_constraint(:owner)
    |> unique_constraint(:name, name: :repositories_owner_id_name_index)
    |> put_maintainers(params)
  end

  @doc """
  Creates a new repository.
  """
  @spec create(map|keyword, keyword) :: {:ok, t, Git.repo} | {:error, Ecto.Changeset.t | term}
  def create(params, opts \\ []) do
    case multi_create(changeset(%__MODULE__{}, Map.new(params)), Keyword.get(opts, :bare, true)) do
      {:ok, %{insert: repo, init: ref}} -> {:ok, repo, ref}
      {:error, :insert, changeset, _changes} -> {:error, changeset}
      {:error, :init, reason, _changes} -> {:error, reason}
      {:error, :init_maintainer, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Similar to `create/2`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec create!(map|keyword, keyword) :: {t, pid}
  def create!(params, opts \\ []) do
    case create(params, opts) do
      {:ok, repo, pid} -> {repo, pid}
      {:error, changeset} -> raise Ecto.InvalidChangesetError, action: changeset.action, changeset: changeset
    end
  end

  @doc """
  Updates the given `repo` with the given `params`.
  """
  @spec update(t, map|keyword) :: {:ok, t} | {:error, Ecto.Changeset.t | :file.posix}
  def update(%__MODULE__{} = repo, params) do
    case multi_update(changeset(repo, Map.new(params))) do
      {:ok, %{update: repo}} -> {:ok, repo}
      {:error, :update, changeset, _changes} -> {:error, changeset}
      {:error, :rename, reason, _changes} -> {:error, reason}
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
  """
  @spec delete(t) :: {:ok, t} | {:error, Ecto.Changeset.t}
  def delete(%__MODULE__{} = repo) do
    case multi_delete(repo) do
      {:ok, %{delete: repo}} -> {:ok, repo}
      {:error, :delete, changeset, _changes} -> {:error, changeset}
      {:error, :cleanup, reason, _changes} -> {:error, reason}
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

  @doc """
  Returns the number of maintainers for the given `repo`.
  """
  @spec maintainer_count(Repo.t) :: non_neg_integer
  def maintainer_count(%__MODULE__{maintainers: maintainers} = _repo) when is_list(maintainers), do: length(maintainers)
  def maintainer_count(%__MODULE__{} = repo) do
    DB.aggregate(assoc(repo, :maintainers), :count, :id) || 0
  end

  @doc """
  Returns the absolute path to the Git workdir for the given `repo`.
  """
  @spec workdir(t) :: Path.t
  def workdir(%__MODULE__{} = repo) do
    repo = DB.preload(repo, :owner)
    Path.join([root_path(), repo.owner.username, repo.name])
  end

  @doc """
  Returns `true` if `repo` is empty; otherwhise returns `false`.
  """
  @spec empty?(t) :: boolean
  def empty?(%__MODULE__{} = repo) do
    with {:ok, handle} <- Git.repository_open(workdir(repo)), do:
      Git.repository_empty?(handle)
  end

  @doc """
  Returns the Git reference pointed at by *HEAD*.
  """
  @spec git_head(t) :: {:ok, GitReference.t} | {:error, term}
  def git_head(%__MODULE__{} = repo) do
    with {:ok, handle} <- Git.repository_open(workdir(repo)),
         {:ok, name, shorthand, oid} <- Git.reference_resolve(handle, "HEAD"), do:
      {:ok, resolve_reference({name, shorthand, :oid, oid}, {repo, handle})}
  end

  @doc """
  Returns the Git reference matching the given `name_or_shorthand`.
  """
  @spec git_reference(t, binary) :: {:ok, GitReference.t} | {:error, term}
  def git_reference(repo, name_or_shorthand \\ :head)
  def git_reference(%__MODULE__{} = repo, :head), do: git_head(repo)
  def git_reference(%__MODULE__{} = repo, "/refs/" <> _suffix = name) do
    with {:ok, handle} <- Git.repository_open(workdir(repo)),
         {:ok, shorthand, :oid, oid} <- Git.reference_lookup(handle, name), do:
      {:ok, resolve_reference({name, shorthand, :oid, oid}, {repo, handle})}
  end

  def git_reference(%__MODULE__{} = repo, shorthand) do
    with {:ok, handle} <- Git.repository_open(workdir(repo)),
         {:ok, name, :oid, oid} <- Git.reference_dwim(handle, shorthand), do:
      {:ok, resolve_reference({name, shorthand, :oid, oid}, {repo, handle})}
  end

  @doc """
  Returns all Git references matching the given `glob`.
  """
  @spec git_references(t, binary | :undefined) :: {:ok, Stream.t} | {:error, term}
  def git_references(%__MODULE__{} = repo, glob \\ :undefined) do
    with {:ok, handle} <- Git.repository_open(workdir(repo)),
         {:ok, stream} <- Git.reference_stream(handle, glob),
         {:ok, stream} <- Git.enumerate(stream), do:
      {:ok, Stream.map(stream, &resolve_reference(&1, {repo, handle}))}
  end

  @doc """
  Returns a Git branch for the given `branch_name`.
  """
  @spec git_branch(t, binary) :: {:ok, GitReference.t} | {:error, term}
  def git_branch(%__MODULE__{} = repo, branch_name) do
    name = "refs/heads/" <> branch_name
    with {:ok, handle} <- Git.repository_open(workdir(repo)),
         {:ok, shorthand, :oid, oid} <- Git.reference_lookup(handle, name), do:
      {:ok, resolve_reference({name, shorthand, :oid, oid}, {repo, handle})}
  end

  @doc """
  Returns all Git branches.
  """
  @spec git_branches(t) :: {:ok, Stream.t} | {:error, term}
  def git_branches(%__MODULE__{} = repo) do
    with {:ok, handle} <- Git.repository_open(workdir(repo)),
         {:ok, stream} <- Git.reference_stream(handle, "refs/heads/*"),
         {:ok, stream} <- Git.enumerate(stream), do:
      {:ok, Stream.map(stream, &resolve_reference(&1, {repo, handle}))}
  end

  @doc """
  Returns a Git tag for the given `tag_name`.
  """
  @spec git_tag(t, binary) :: {:ok, GitReference.t | GitTag.t} | {:error, term}
  def git_tag(%__MODULE__{} = repo, tag_name) do
    name = "refs/tags/" <> tag_name
    with {:ok, handle} <- Git.repository_open(workdir(repo)),
         {:ok, shorthand, :oid, oid} <- Git.reference_lookup(handle, name), do:
      {:ok, resolve_tag({name, shorthand, :oid, oid}, {repo, handle})}
  end

  @doc """
  Returns all Git tags.
  """
  @spec git_tags(t) :: {:ok, Stream.t} | {:error, term}
  def git_tags(%__MODULE__{} = repo) do
    with {:ok, handle} <- Git.repository_open(workdir(repo)),
         {:ok, stream} <- Git.reference_stream(handle, "refs/tags/*"),
         {:ok, stream} <- Git.enumerate(stream), do:
      {:ok, Stream.map(stream, &resolve_tag(&1, {repo, handle}))}
  end

  @doc """
  Returns the Git object matching the given `revision`.
  """
  @spec git_revision(t, binary) :: {:ok, git_object} | {:error, term}
  def git_revision(%__MODULE__{} = repo, revision) do
    with {:ok, handle} <- Git.repository_open(workdir(repo)),
         {:ok, obj, obj_type, oid} <- Git.revparse_single(handle, revision), do:
      {:ok, resolve_object({obj, obj_type, oid}, repo)}
  end

  @doc """
  Returns the absolute path to the Git root directory.
  """
  @spec root_path() :: Path.t | nil
  def root_path() do
    Path.absname(Application.fetch_env!(:gitgud, :git_root), Application.app_dir(:gitgud))
  end

  @doc """
  Broadcasts notification(s) for the given `service` command.
  """
  @spec notify_command(t, User.t, struct) :: :ok
  def notify_command(%__MODULE__{} = repo, %User{} = user, %GitRekt.WireProtocol.ReceivePack{state: :done, cmds: cmds} = _service) do
    IO.puts "push notification from #{user.username} to #{repo.name}"
    Enum.each(cmds, fn
      {:create, oid, refname} ->
        IO.puts "create #{refname} to #{Git.oid_fmt(oid)}"
      {:update, old_oid, new_oid, refname} ->
        IO.puts "update #{refname} from #{Git.oid_fmt(old_oid)} to #{Git.oid_fmt(new_oid)}"
      {:delete, old_oid, refname} ->
        IO.puts "delete #{refname} (was #{Git.oid_fmt(old_oid)})"
    end)
  end

  def notify_command(%__MODULE__{} = _repo, _user, _service), do: :ok

  #
  # Protocols
  #

  defimpl GitGud.AuthorizationPolicies do
    alias GitGud.Repo

    # everybody can read public repos
    def can?(%Repo{public: true}, _user, :read), do: true

    # owner can do everything
    def can?(%Repo{owner_id: user_id}, %User{id: user_id}, _action), do: true

    # maintainers can read and write
    def can?(%Repo{} = repo, %User{id: user_id}, action) when action in [:read, :write] do
      repo = DB.preload(repo, :maintainers)
      !!Enum.find(repo.maintainers, false, fn
        %User{id: ^user_id} -> true
        %User{} -> nil
      end)
    end

    # everything-else is forbidden
    def can?(%Repo{}, _user, _actions), do: false
  end

  #
  # Helpers
  #

  defp put_maintainers(changeset, params) do
    try do
      put_assoc(changeset, :maintainers, parse_maintainers(params))
    catch
      username ->
        add_error(changeset, :maintainers, "invalid username #{username}")
    end
  end

  defp parse_maintainers(params) do
    params
    |> Map.get("maintainers", "")
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(& &1 == "")
    |> Enum.map(&fetch_maintainer/1)
  end

  defp fetch_maintainer(username) do
    if user = UserQuery.by_username(username),
      do: user,
    else: throw(username)
  end

  defp multi_create(changeset, bare?) do
    Multi.new()
    |> Multi.insert(:insert, changeset)
    |> Multi.run(:init, &init(&1, bare?))
    |> Multi.merge(&init_maintainer/1)
    |> DB.transaction()
  end

  defp multi_update(changeset) do
    Multi.new()
    |> Multi.update(:update, changeset)
    |> Multi.run(:rename, &rename(&1, changeset.data))
    |> DB.transaction()
  end

  defp multi_delete(repo) do
    Multi.new()
    |> Multi.delete(:delete, repo)
    |> Multi.run(:cleanup, &cleanup/1)
    |> DB.transaction()
  end

  defp init(%{insert: repo}, bare?) do
    Git.repository_init(workdir(repo), bare?)
  end

  defp init_maintainer(%{insert: repo}) do
    Multi.insert_all(Multi.new(), :init_maintainer, "repositories_maintainers", [[repo_id: repo.id, user_id: repo.owner_id]])
  end

  defp rename(%{update: repo}, old_repo) do
    old_workdir = workdir(old_repo)
    new_workdir = workdir(repo)
    case File.rename(old_workdir, new_workdir) do
      :ok -> {:ok, {old_workdir, new_workdir}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp cleanup(%{delete: repo}) do
    File.rm_rf(workdir(repo))
  end

  defp resolve_object({blob, :blob, oid}, repo), do: %GitBlob{oid: oid, repo: repo, __git__: blob}
  defp resolve_object({commit, :commit, oid}, repo), do: %GitCommit{oid: oid, repo: repo, __git__: commit}
  defp resolve_object({tag, :tag, oid}, repo), do: %GitTag{oid: oid, repo: repo, __git__: tag}
  defp resolve_object({tree, :tree, oid}, repo), do: %GitTree{oid: oid, repo: repo, __git__: tree}

  defp resolve_reference({name, shorthand, :oid, oid}, {repo, handle}) do
    prefix = String.slice(name, 0, String.length(name) - String.length(shorthand))
    %GitReference{oid: oid, name: shorthand, prefix: prefix, repo: repo, __git__: handle}
  end

  defp resolve_tag({name, shorthand, :oid, oid}, {repo, handle}) do
    case Git.reference_peel(handle, name, :tag) do
      {:ok, :tag, oid, tag} ->
        %GitTag{oid: oid, repo: repo, __git__: tag}
      {:error, _reason} ->
        resolve_reference({name, shorthand, :oid, oid}, {repo, handle})
    end
  end
end
