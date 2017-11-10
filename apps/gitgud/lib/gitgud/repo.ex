defmodule GitGud.Repo do
  @moduledoc """
  Repository schema and helper functions.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Ecto.Multi

  alias GitRekt.Git

  alias GitGud.User
  alias GitGud.QuerySet

  @root_path Application.fetch_env!(:gitgud, :git_dir)

  schema "repositories" do
    belongs_to  :owner,       User
    field       :path,        :string
    field       :name,        :string
    field       :description, :string
    timestamps()
  end

  @type t :: %__MODULE__{
    id: pos_integer,
    owner_id: pos_integer,
    owner: User.t,
    path: binary,
    name: binary,
    description: binary,
    inserted_at: NaiveDateTime.t,
    updated_at: NaiveDateTime.t,
  }

  @doc """
  Returns `true` if `user` has read access to `repo`; elsewhise returns `false`.
  """
  @spec can_read?(User.t, t) :: boolean
  def can_read?(%User{} = _user, %__MODULE__{} = _repo), do: true
  def can_read?(_user, _repo), do: true

  @doc """
  Returns the absolute path to the Git workdir for the given `repo`.
  """
  @spec workdir(t) :: Path.t
  def workdir(%__MODULE__{} = repo) do
    repo = QuerySet.preload(repo, :owner)
    Path.join([@root_path, repo.owner.username, repo.path])
  end

  @doc """
  Returns `true` if `user` has write access to `repo`; elsewhise returns `false`.
  """
  @spec can_write?(User.t, t) :: boolean
  def can_write?(%User{id: user_id} = _user, %__MODULE__{owner_id: user_id} = _repo), do: true
  def can_write?(_user, _repo), do: false

  @doc """
  Returns a repository changeset for the given `params`.
  """
  @spec changeset(t, map) :: Ecto.Changeset.t
  def changeset(%__MODULE__{} = repository, params \\ %{}) do
    repository
    |> cast(params, [:owner_id, :path, :name, :description])
    |> validate_required([:owner_id, :path, :name])
    |> validate_format(:path, ~r/^[a-zA-Z0-9_-]+$/)
    |> validate_length(:path, min: 3)
    |> validate_length(:name, min: 3, max: 80)
    |> assoc_constraint(:owner)
    |> unique_constraint(:path, name: :repositories_path_owner_id_index)
  end

  @doc """
  Creates a new repository.
  """
  @spec create(map|keyword, keyword) :: {:ok, t, Git.repo} | {:error, Ecto.Changeset.t}
  def create(params, opts \\ []) do
    bare? = Keyword.get(opts, :bare?, true)
    changeset = changeset(%__MODULE__{}, Map.new(params))
    case insert_and_init(changeset, bare?) do
      {:ok, %{insert: repo, init_repo: ref}} -> {:ok, repo, ref}
      {:error, :insert, changeset, _changes} -> {:error, changeset}
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
  @spec update(t, map|keyword) :: {:ok, t} | {:error, Ecto.Changeset.t}
  def update(%__MODULE__{} = repo, params) do
    changeset = changeset(repo, Map.new(params))
    case update_and_fix_path(changeset) do
      {:ok, %{update: repo}} -> {:ok, repo}
      {:error, :update, changeset, _changes} -> {:error, changeset}
    end
  end

  @doc """
  Similar to `update/2`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec update!(t, map|keyword) :: t
  def update!(%__MODULE__{} = repo, params) do
    case update(repo, params) do
      {:ok, repo} -> repo
      {:error, changeset} -> raise Ecto.InvalidChangesetError, action: changeset.action, changeset: changeset
    end
  end

  @doc """
  Deletes the given `repo`.
  """
  @spec delete(t) :: {:ok, t} | {:error, Ecto.Changeset.t}
  def delete(%__MODULE__{} = repo) do
    case delete_and_cleanup(repo) do
      {:ok, %{delete: repo}} -> {:ok, repo}
      {:error, :delete, changeset, _changes} -> {:error, changeset}
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

  #
  # Helpers
  #

  defp insert_and_init(changeset, bare?) do
    Multi.new()
    |> Multi.insert(:insert, changeset)
    |> Multi.run(:init_repo, fn %{insert: repo} -> init_repo(repo, bare?) end)
    |> QuerySet.transaction()
  end

  defp init_repo(repo, bare?) do
    repo = QuerySet.preload(repo, :owner)
    @root_path
    |> Path.join(repo.owner.username)
    |> Path.join(repo.path)
    |> Git.repository_init(bare?)
  end

  defp update_and_fix_path(changeset) do
    Multi.new()
    |> Multi.update(:update, changeset)
    |> Multi.run(:rename_repo, fn %{update: repo} -> rename_repo(changeset.data, repo) end)
    |> QuerySet.transaction()
  end

  defp rename_repo(%__MODULE__{} = old_repo, %__MODULE__{} = new_repo) do
    old_repo = QuerySet.preload(old_repo, :owner)
    old_path = Path.join(old_repo.owner.username, old_repo.path)
    new_repo = QuerySet.preload(new_repo, :owner)
    new_path = Path.join(new_repo.owner.username, new_repo.path)
    if old_path != new_path,
      do: rename_repo(old_path, new_path),
    else: {:ok, :noop}
  end

  defp rename_repo(old_path, new_path) do
    case File.rename(Path.join(@root_path, old_path), Path.join(@root_path, new_path)) do
      :ok -> {:ok, new_path}
      {:error, reason} -> {:error, reason}
    end
  end

  defp delete_and_cleanup(repo) do
    Multi.new()
    |> Multi.delete(:delete, repo)
    |> Multi.run(:remove_repo, fn %{delete: repo} -> remove_repo(repo) end)
    |> QuerySet.transaction()
  end

  defp remove_repo(repo) do
    repo = QuerySet.preload(repo, :owner)
    File.rm_rf(Path.join([@root_path, repo.owner.username, repo.path]))
  end
end
