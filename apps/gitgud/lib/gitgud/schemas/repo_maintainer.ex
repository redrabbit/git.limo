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

  schema "repositories_maintainers" do
    belongs_to :user, User
    belongs_to :repo, Repo
    field :permission, :string
    timestamps()
  end

  @type t :: %__MODULE__{
    user_id: pos_integer,
    user: User.t,
    repo_id: pos_integer,
    repo: Repo.t,
    permission: binary,
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
  Updates the `permission` of the given `maintainer`.
  """
  @spec update_permission(t, binary) :: {:ok, t} | {:error, Ecto.Changeset.t}
  def update_permission(%__MODULE__{} = maintainer, permission) do
    DB.update(changeset(maintainer, %{permission: permission}))
  end

  @doc """
  Similar to `update_permission/2`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec update_permission!(t, binary) :: t
  def update_permission!(%__MODULE__{} = maintainer, permission) do
    DB.update!(changeset(maintainer, %{permission: permission}))
  end

  @spec delete(t) :: {:ok, t} | {:error, Ecto.Changeset.t}
  def delete(%__MODULE__{} = maintainer) do
    DB.delete(maintainer)
  end

  @spec delete(t) :: t
  def delete!(%__MODULE__{} = maintainer) do
    DB.delete!(maintainer)
  end

  @doc """
  Returns a maintainer changeset for the given `params`.
  """
  @spec changeset(t, map) :: Ecto.Changeset.t
  def changeset(%__MODULE__{} = maintainer, params \\ %{}) do
    maintainer
    |> cast(params, [:user_id, :repo_id, :permission])
    |> validate_required([:user_id, :repo_id])
    |> unique_constraint(:user_id, name: "repositories_maintainers_user_id_repo_id_index")
    |> validate_inclusion(:permission, ["read", "write", "admin"])
  end
end
