defmodule GitGud.Maintainer do
  @moduledoc """
  Repository maintainer schema and helper functions.

  A `GitGud.Maintainer` is used to grant `GitGud.Repo` permissions to a given `GitGud.User`.

  Each repository maintainer also has a permission defining which actions he is able to perform
  on the repository. Following permissions are available:

  * `:read` -- can read and clone the repository.
  * `:write` -- can read, clone and push to the repository.
  * `:admin` -- can read, clone, push and administrate the repository.

  By default, a newly created repository maintainer has `:read` permission.
  """

  use Ecto.Schema

  alias GitGud.DB
  alias GitGud.User
  alias GitGud.Repo

  import Ecto.Query, only: [from: 2]
  import Ecto.Changeset

  schema "maintainers" do
    belongs_to :user, User
    belongs_to :repo, Repo
    field :permission, :string, default: "read"
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
  Updates the `permission` of the given `maintainer`.

  ```elixir
  {:ok, maintainer} = GitGud.Maintainer.update_permission(maintainer, :write)
  ```

  This function validates the given `permission` using `changeset/2`.
  """
  @spec update_permission(t, binary) :: {:ok, t} | {:error, Ecto.Changeset.t}
  def update_permission(%__MODULE__{} = maintainer, permission) do
    DB.update(changeset(maintainer, %{permission: permission}))
  end

  @doc """
  Updates the `permission` of the given `user` for the given `repo`.

  ```elixir
  {:ok, maintainer} = GitGud.Maintainer.update_permission(repo, user, :write)
  ```

  This function validates the given `permission` using `changeset/2`.
  """
  @spec update_permission(Repo.t, User.t, binary) :: {:ok, t} | :error
  def update_permission(%Repo{id: repo_id} = _repo, %User{id: user_id} = _user, permission) do
    query = from(m in __MODULE__, where: m.repo_id == ^repo_id and m.user_id == ^user_id)
    case DB.update_all(query, [set: [permission: permission]], returning: true) do
      {1, [maintainer]} -> {:ok, maintainer}
      {0, []} -> :error
    end
  end

  @doc """
  Similar to `update_permission/2`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec update_permission!(t, binary) :: t
  def update_permission!(%__MODULE__{} = maintainer, permission) do
    DB.update!(changeset(maintainer, %{permission: permission}))
  end

  @doc """
  Similar to `update_permission/3`, but raises an `Ecto.NoResultsError` if an error occurs.
  """
  @spec update_permission!(Repo.t, User.t, binary) :: t
  def update_permission!(%Repo{} = repo, %User{} = user, permission) do
    case update_permission(repo, user, permission) do
      {:ok, maintainer} -> maintainer
      :error -> raise Ecto.NoResultsError
    end
  end

  @doc """
  Deletes the given `maintainer`.

  ```elixir
  {:ok, maintainer} = GitGud.Maintainer.delete(maintainer)
  ```
  """
  @spec delete(t) :: {:ok, t} | {:error, Ecto.Changeset.t}
  def delete(%__MODULE__{} = maintainer) do
    DB.delete(maintainer)
  end

  @doc """
  Similar to `delete!/1`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec delete(t) :: t
  def delete!(%__MODULE__{} = maintainer) do
    DB.delete!(maintainer)
  end

  @doc """
  Returns a changeset for the given `params`.
  """
  @spec changeset(t, map) :: Ecto.Changeset.t
  def changeset(%__MODULE__{} = maintainer, params \\ %{}) do
    maintainer
    |> cast(params, [:user_id, :permission])
    |> validate_required([:user_id])
    |> unique_constraint(:user_id, name: "maintainers_user_id_repo_id_index")
    |> validate_inclusion(:permission, ["read", "write", "admin"])
  end
end
