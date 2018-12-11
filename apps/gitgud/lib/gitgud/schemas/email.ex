defmodule GitGud.Email do
  @moduledoc """
  Email schema and helper functions.

  An `GitGud.Email` is used for a many different tasks such as user authentication & verification,
  email notifications, identification of Git commit authors, etc.

  Every `GitGud.User` has **at least one** email address. In order to be taken in account, an email address
  must be verified first. See `verify/1` for more details.

  Once verified, an email address can be used to authenticate users (see `GitGud.Auth.check_credentials/2`)
  and resolve Git commit authors.

  In order to associate Git commits to a specific `GitGud.User` account, every user can have has many email
  addresses as he likes. Once verified, emails appearing in Git commits will automatically be linked to the
  associated user. See `GitGud.GPGKey` for more details on how to verify GPG (or S/MIME) signed commits.
  """

  use Ecto.Schema

  alias GitGud.DB
  alias GitGud.User

  alias Ecto.Multi

  import Ecto.Query, only: [from: 2]
  import Ecto.Changeset

  schema "users_emails" do
    belongs_to :user, User
    field      :address, :string
    field      :verified, :boolean, default: false
    timestamps(updated_at: false)
    field      :verified_at, :naive_datetime
  end

  @type t :: %__MODULE__{
    id: pos_integer,
    user_id: pos_integer,
    user: User.t,
    address: binary,
    verified: boolean,
    inserted_at: NaiveDateTime.t,
    verified_at: NaiveDateTime.t
  }

  @doc """
  Creates a new email with the given `params`.

  ```elixir
  {:ok, email} = GitGud.Email.create(user_id: user.id, address: "m.flach@almightycouch.com")
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
  Verifies the given `email`.
  """
  @spec verify(t) :: {:ok, t} | {:error, Ecto.Changeset.t}
  def verify(%__MODULE__{} = email) do
    changeset = change(email, %{verified: true, verified_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)})
    changeset = check_constraint(changeset, :address, name: :users_emails_address_constraint, message: "already taken")
    case DB.transaction(verify_email_multi(changeset)) do
      {:ok, %{email: email}} ->
        {:ok, email}
      {:error, _operation, changeset, _changes} ->
        {:error, changeset}
    end
  end

  @doc """
  Similar to `verify/1`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec verify!(t) :: t
  def verify!(%__MODULE__{} = email) do
    case verify(email) do
      {:ok, email} -> email
      {:error, changeset} -> raise Ecto.InvalidChangesetError, action: changeset.action, changeset: changeset
    end
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
    |> cast(params, [:user_id, :address])
    |> validate_required([:address])
    |> validate_format(:address, ~r/^([a-zA-Z0-9_\-\.]+)@([a-zA-Z0-9_\-\.]+)\.([a-zA-Z]{2,5})$/)
    |> assoc_constraint(:user)
    |> check_constraint(:address, name: :users_emails_address_constraint, message: "already taken")
    |> unique_constraint(:address, name: :users_emails_user_id_address_index)
  end

  #
  # Helpers
  #

  defp verify_email_multi(changeset) do
    email_address = get_field(changeset, :address)
    Multi.new()
    |> Multi.update(:email, changeset)
    |> Multi.delete_all(:unverified_emails, from(e in __MODULE__, where: e.verified == false and e.address == ^email_address))
    |> Multi.run(:user, &update_user_primary_email/2)
  end

  defp update_user_primary_email(db, %{email: email}) do
      email = db.preload(email, :user)
      if email.user.primary_email_id,
        do: {:ok, email.user},
      else: db.update(change(email.user, %{primary_email_id: email.id}))
  end
end
