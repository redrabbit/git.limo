defmodule GitGud.Repository do
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
  Creates a new repository.
  """
  @spec create(map, keyword) :: {:ok, t, pid} | {:error, term}
  def create(params, opts \\ []) do
    bare? = Keyword.get(opts, :bare?, true)
    changeset = changeset(%__MODULE__{}, params)
    case insert_and_init(changeset, bare?) do
      {:ok, %{insert: repo, geef_repo: pid}} ->
        {:ok, repo, pid}
      {:error, _operation, reason, _changes} ->
        {:error, reason}
    end
  end

  @doc """
  Similar to `create/2`, but raises an ArgumentError if an error occurs.
  """
  @spec create!(map, keyword) :: {t, pid}
  def create!(params, opts \\ []) do
    case create!(params, opts) do
      {:ok, repo, pid} -> {repo, pid}
      {:error, reason} -> raise ArgumentError, message: reason
    end
  end

  @doc """
  Initializes a new Git repository from the given `repo`.
  """
  @spec init(t, boolean) :: {:ok, pid} | {:error, term}
  def init(repo, bare? \\ true) do
    Geef.Repository.init(Path.join(@root_path, repo.path), bare?)
  end

  @doc """
  Similar to `init/2`, but raises an ArgumentError if an error occurs.
  """
  @spec init!(t, boolean) :: pid
  def init!(repo, bare? \\ true) do
    case init(repo, bare?) do
      {:ok, pid} -> pid
      {:error, reason} -> raise ArgumentError, message: reason
    end
  end

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

  @spec changeset(t, map) :: Ecto.Changeset.t
  def changeset(%__MODULE__{} = repository, params \\ %{}) do
    repository
    |> cast(params, [:owner_id, :path, :name, :description])
    |> validate_required([:owner_id, :path, :name])
    |> validate_format(:path, ~r/^[a-zA-Z0-9_-]+$/)
    |> validate_length(:name, min: 3, max: 80)
    |> unique_constraint(:path)
    |> assoc_constraint(:owner)
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
