defmodule GitGud.Repository do
  @moduledoc """
  Git repository schema and helper functions.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Ecto.Multi

  alias GitGud.Repo
  alias GitGud.User

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
  def can_read?(_user, _repo), do: false

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
    |> validate_length(:name, min: 3, max: 80)
    |> assoc_constraint(:owner)
    |> unique_constraint(:path, name: :repositories_path_owner_id_index)
  end

  @doc """
  Creates a new repository.
  """
  @spec create(map, keyword) :: {:ok, t, pid} | {:error, Ecto.Changeset.t}
  def create(params, opts \\ []) do
    bare? = Keyword.get(opts, :bare?, true)
    changeset = changeset(%__MODULE__{}, params)
    case insert_and_init(changeset, bare?) do
      {:ok, %{insert: repo, geef_repo: pid}} ->
        {:ok, repo, pid}
      {:error, :insert, changeset, _changes} ->
        {:error, changeset}
    end
  end

  @doc """
  Similar to `create/2`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec create!(map, keyword) :: {t, pid}
  def create!(params, opts \\ []) do
    case create!(params, opts) do
      {:ok, repo, pid} -> {repo, pid}
      {:error, changeset} -> raise Ecto.InvalidChangesetError, action: changeset.action, changeset: changeset
    end
  end

  @doc """
  Initializes a new Git repository from the given `repo`.
  """
  @spec init(t, boolean) :: {:ok, pid} | {:error, term}
  def init(repo, bare? \\ true) do
    repo = Repo.preload(repo, :owner)
    @root_path
    |> Path.join(repo.owner.username)
    |> Path.join(repo.path)
    |> Geef.Repository.init(bare?)
  end

  @doc """
  Similar to `init/2`, but raises an `ArgumentError` if an error occurs.
  """
  @spec init!(t, boolean) :: pid
  def init!(repo, bare? \\ true) do
    case init(repo, bare?) do
      {:ok, pid} -> pid
      {:error, reason} -> raise ArgumentError, message: reason
    end
  end

  @doc """
  Updates the given `repo` with the given `params`.
  """
  @spec update(t, map) :: {:ok, t} | {:error, Ecto.Changeset.t}
  def update(%__MODULE__{} = repo, params) do
    Repo.update(changeset(repo, params))
  end

  @doc """
  Similar to `update/2`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec update!(t, map) :: t
  def update!(%__MODULE__{} = repo, params) do
    Repo.update!(changeset(repo, params))
  end

  @doc """
  Deletes the given `repo`.
  """
  @spec delete(t) :: {:ok, t} | {:error, Ecto.Changeset.t}
  def delete(%__MODULE__{} = repo) do
    Repo.delete(repo)
  end

  @doc """
  Similar to `delete!/1`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec delete!(t) :: t
  def delete!(%__MODULE__{} = repo) do
    Repo.delete!(repo)
  end

  #
  # Helpers
  #

  defp insert_and_init(changeset, bare?) do
    Multi.new()
    |> Multi.insert(:insert, changeset)
    |> Multi.run(:geef_repo, fn %{insert: repo} -> init(repo, bare?) end)
    |> Repo.transaction()
  end
end
