defmodule GitGud.Repo do
  @moduledoc """
  Repository schema and helper functions.
  """

  use Ecto.Schema

  alias Ecto.Multi

  alias GitRekt.Git
  alias GitRekt.WireProtocol.ReceivePack

  alias GitGud.DB
  alias GitGud.User
  alias GitGud.UserQuery

  alias GitGud.GitBlob
  alias GitGud.GitCommit
  alias GitGud.GitReference
  alias GitGud.GitTag
  alias GitGud.GitTree

  import Ecto.Changeset

  schema "repositories" do
    belongs_to    :owner,       User
    field         :name,        :string
    field         :public,      :boolean, default: true
    field         :description, :string
    many_to_many  :maintainers, User, join_through: "repositories_maintainers", on_replace: :delete, on_delete: :delete_all
    timestamps()
  end

  @type git_object :: GitBlob.t | GitCommit.t | GitTag.t | GitTree.t
  @type git_revision :: GitReference.t | GitTag.t | GitCommit.t

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
  Returns the Git object matching the given `oid`.
  """
  @spec git_object(t, binary) :: {:ok, git_object} | {:error, term}
  def git_object(%__MODULE__{} = repo, oid) do
    oid = Git.oid_parse(oid)
    with {:ok, handle} <- Git.repository_open(workdir(repo)),
         {:ok, obj_type, obj} <- Git.object_lookup(handle, oid), do:
      {:ok, resolve_object({obj, obj_type, oid}, {repo, handle})}
  end

  @doc """
  Returns the Git object matching the given `revision`.
  """
  @spec git_revision(t, binary) :: {:ok, git_object, GitReference.t | nil} | {:error, term}
  def git_revision(%__MODULE__{} = repo, revision) do
    with {:ok, handle} <- Git.repository_open(workdir(repo)),
         {:ok, obj, obj_type, oid, name} <- Git.revparse_ext(handle, revision), do:
      {:ok, resolve_object({obj, obj_type, oid}, {repo, handle}), resolve_reference({name, nil, :oid, oid}, {repo, handle})}
  end

  @doc """
  Returns the commit history starting from the given `revision`.
  """
  @spec git_history(git_revision) :: {:ok, Stream.t} | {:error, term}
  def git_history(%GitReference{oid: oid, repo: repo, __git__: handle} = _revision) do
    resolve_history(oid, {repo, handle})
  end

  def git_history(%GitTag{oid: oid, repo: repo, __git__: tag} = _revision) do
    case Git.object_repository(tag) do
      {:ok, handle} -> resolve_history(oid, {repo, handle})
      {:error, reason} -> {:error, reason}
    end
  end

  def git_history(%GitCommit{oid: oid, repo: repo, __git__: commit} = _revision) do
    case Git.object_repository(commit) do
      {:ok, handle} -> resolve_history(oid, {repo, handle})
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns the tree of the given `revision`.
  """
  @spec git_tree(git_revision) :: {:ok, GitTree.t} | {:error, term}
  def git_tree(%GitReference{name: name, prefix: prefix, repo: repo, __git__: handle} = _revision) do
    with {:ok, :commit, _oid, commit} <- Git.reference_peel(handle, prefix <> name, :commit),
         {:ok, oid, tree} <- Git.commit_tree(commit), do:
      {:ok, %GitTree{oid: oid, repo: repo, __git__: tree}}
  end

  def git_tree(%GitTag{repo: repo, __git__: tag} = _revision) do
    with {:ok, :commit, _oid, commit} <- Git.tag_peel(tag),
         {:ok, oid, tree} <- Git.commit_tree(commit), do:
      {:ok, %GitTree{oid: oid, repo: repo, __git__: tree}}
  end

  def git_tree(%GitCommit{repo: repo, __git__: commit} = _revision) do
    with {:ok, oid, tree} <- Git.commit_tree(commit), do:
      {:ok, %GitTree{oid: oid, repo: repo, __git__: tree}}
  end

  @doc """
  Returns the absolute path to the Git root directory.
  """
  @spec root_path() :: Path.t | nil
  def root_path() do
    Path.absname(Application.fetch_env!(:gitgud, :git_root), Application.app_dir(:gitgud))
  end

  @doc """
  Applies the given `receive_pack` command to the `repo`.
  """
  @spec git_push(t, ReceivePack.t) :: :ok | {:error, term}
  def git_push(%__MODULE__{} = repo, %ReceivePack{repo: handle, pack: pack, cmds: cmds} = _receive_pack) do
    case Git.repository_get_odb(handle) do
      {:ok, odb} ->
        oids = Enum.map(pack, &apply_pack_obj(odb, &1))
        :ok = Enum.each(cmds, &apply_pack_cmd(handle, &1))
        :ok = Phoenix.PubSub.broadcast(GitGud.Web.PubSub, "repos:#{repo.id}", {:push, %{repo_id: repo.id, cmds: cmds, oids: oids}})
      {:error, reason} ->
        {:error, reason}
    end
  end

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

  defp resolve_history(oid, {repo, handle}) do
    with {:ok, walk} <- Git.revwalk_new(handle),
          :ok <- Git.revwalk_push(walk, oid),
         {:ok, stream} <- Git.revwalk_stream(walk),
         {:ok, stream} <- Git.enumerate(stream), do:
      {:ok, Stream.map(stream, &resolve_object(&1, {repo, handle}))}
  end

  defp resolve_reference({nil, nil, :oid, _oid}, {_repo, _handle}), do: nil
  defp resolve_reference({name, nil, :oid, oid}, {repo, handle}) do
    prefix = Path.dirname(name) <> "/"
    shorthand = Path.basename(name)
    %GitReference{oid: oid, name: shorthand, prefix: prefix, repo: repo, __git__: handle}
  end

  defp resolve_reference({name, shorthand, :oid, oid}, {repo, handle}) do
    prefix = String.slice(name, 0, String.length(name) - String.length(shorthand))
    %GitReference{oid: oid, name: shorthand, prefix: prefix, repo: repo, __git__: handle}
  end

  defp resolve_tag({name, shorthand, :oid, oid}, {repo, handle}) do
    case Git.reference_peel(handle, name, :tag) do
      {:ok, :tag, oid, tag} ->
        %GitTag{oid: oid, name: shorthand, repo: repo, __git__: tag}
      {:error, _reason} ->
        resolve_reference({name, shorthand, :oid, oid}, {repo, handle})
    end
  end

  defp resolve_object({blob, :blob, oid}, {repo, _handle}), do: %GitBlob{oid: oid, repo: repo, __git__: blob}
  defp resolve_object({commit, :commit, oid}, {repo, _handle}), do: %GitCommit{oid: oid, repo: repo, __git__: commit}
  defp resolve_object({tree, :tree, oid}, {repo, _handle}), do: %GitTree{oid: oid, repo: repo, __git__: tree}
  defp resolve_object({tag, :tag, oid}, {repo, _handle}) do
    case Git.tag_name(tag) do
      {:ok, name} -> %GitTag{oid: oid, name: name, repo: repo, __git__: tag}
      {:error, _reason} -> nil
    end
  end

  defp resolve_object(oid, {repo, handle}) do
    case Git.object_lookup(handle, oid) do
      {:ok, obj_type, obj} ->
        resolve_object({obj, obj_type, oid}, {repo, handle})
      {:error, _reason} -> nil
    end
  end

  defp apply_pack_obj(odb, {obj_type, obj_data}) do
    case Git.odb_write(odb, obj_data, obj_type) do
      {:ok, oid} -> oid
      {:error, _reason} -> nil
    end
  end

  defp apply_pack_cmd(handle, {:create, new_oid, name}) do
    :ok = Git.reference_create(handle, name, :oid, new_oid, false)
  end

  defp apply_pack_cmd(handle, {:update, _old_oid, new_oid, name}) do
    :ok = Git.reference_create(handle, name, :oid, new_oid, true)
  end

  defp apply_pack_cmd(handle, {:delete, _old_oid, name}) do
    :ok = Git.reference_delete(handle, name)
  end
end
