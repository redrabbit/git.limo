defmodule GitGud.Email do
  @moduledoc """
  Email schema and helper functions.

  An `GitGud.Email` is used for a many different tasks such as user authentication & verification,
  email notifications, identification of Git commit authors, etc.

  ## Email verification

  Every `GitGud.User` has **at least one** email address. In order to be taken in account, an email address
  must be verified first. See `GitGud.Web.EmailController` for implementation details.

  Once verified, an email address can be used to authenticate users (see `GitGud.User.check_credentials/2`)
  and resolve Git commit authors.

  ## Commit association

  In order to associate Git commits to a specific `GitGud.User` account, every user can have has many email
  addresses as he likes. Once verified, emails appearing in Git commits will automatically be linked to the
  associated user. See `GitGud.GPGKey` for more details on how to verify GPG (or S/MIME) signed commits.
  """

  use Ecto.Schema

  alias GitGud.DB
  alias GitGud.User

  import Ecto.Changeset

  schema "emails" do
    belongs_to :user, User
    field      :email, :string
    field      :verified, :boolean, default: false
    timestamps()
  end

  @type t :: %__MODULE__{
    id: pos_integer,
    user_id: pos_integer,
    user: User.t,
    email: binary,
    verified: boolean,
    inserted_at: NaiveDateTime.t,
    updated_at: NaiveDateTime.t
  }

  @doc """
  Creates a new email with the given `params`.

  ```elixir
  {:ok, email} = GitGud.Email.create(user_id: user.id, email: "m.flach@almightycouch.com")
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
  Updates the verification status for the given `email`.
  """
  @spec update_verified(t, boolean) :: {:ok, t} | {:error, Ecto.Changeset.t}
  def update_verified(%__MODULE__{} = email, verified) do
    DB.update(change(email, %{verified: verified}))
  end

  @doc """
  Similar to `update_verified/2`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec update_verified!(t, boolean) :: t
  def update_verified!(%__MODULE__{} = email, verified) do
    DB.update!(change(email, %{verified: verified}))
  end

  @doc """
  Deletes the given `email`.
  """
  @spec delete(t) :: {:ok, t} | {:error, Ecto.Changeset.t}
  def delete(%__MODULE__{} = email) do
    DB.delete(email)
  end

  @doc """
  Similar to `delete!/1`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec delete!(t) :: t
  def delete!(%__MODULE__{} = email) do
    DB.delete!(email)
  end


  @doc """
  Returns an email changeset for the given `params`.
  """
  @spec changeset(t, map) :: Ecto.Changeset.t
  def changeset(%__MODULE__{} = email, params \\ %{}) do
    email
    |> cast(params, [:user_id, :email])
    |> validate_required([:email])
    |> validate_format(:email, ~r/^([a-zA-Z0-9_\-\.]+)@([a-zA-Z0-9_\-\.]+)\.([a-zA-Z]{2,5})$/)
    |> unique_constraint(:email)
    |> foreign_key_constraint(:user_id)
  end
end
