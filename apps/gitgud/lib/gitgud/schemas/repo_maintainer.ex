defmodule GitGud.RepoMaintainer do
  @moduledoc """
  Repository maintainer schema and helper functions.

  A `GitGud.RepoMaintainer` is used to grant repository access to a given `GitGud.User`.
  """

  use Ecto.Schema

  alias GitGud.DB
  alias GitGud.User
  alias GitGud.Repo

  import Ecto.Changeset

  @primary_key false
  schema "repositories_maintainers" do
    belongs_to :user, User
    belongs_to :repo, Repo
    timestamps()
  end

  @type t :: %__MODULE__{
    user_id: pos_integer,
    user: User.t,
    repo_id: pos_integer,
    repo: Repo.t,
    inserted_at: NaiveDateTime.t,
    updated_at: NaiveDateTime.t
  }

  @doc """
  Creates a new maintainer with the given `params`.

  ```elixir
  {:ok, maintainer} = GitGud.RepoMaintainer.create(user_id: user.id, repo_id: repo.id)
  ```

  This function validates the given `params` using `changeset/2`.
  """
  @spec create(map|keyword) :: {:ok, t} | {:error, Ecto.Changeset.t}
  def create(params) do
    DB.insert(changeset(%__MODULE__{}, Map.new(params)))
  end

  @doc """
  Similar to `create/1`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec create!(map|keyword) :: t
  def create!(params) do
    DB.insert!(changeset(%__MODULE__{}, Map.new(params)))
  end

  @doc """
  Returns a maintainer changeset for the given `params`.
  """
  @spec changeset(t, map) :: Ecto.Changeset.t
  def changeset(%__MODULE__{} = maintainer, params \\ %{}) do
    maintainer
    |> cast(params, [:user_id, :repo_id])
    |> validate_required([:user_id, :repo_id])
  end
end
