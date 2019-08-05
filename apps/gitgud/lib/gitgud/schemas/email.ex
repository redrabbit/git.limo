defmodule GitGud.Email do
  @moduledoc """
  Email schema and helper functions.

  An `GitGud.Email` is used for a many different tasks such as user authentication & verification,
  email notifications, identification of Git commit authors, etc.

  Every `GitGud.User` has **at least one** email address. In order to be taken in account, an email address
  must be verified first. See `verify/1` for more details.

  Once verified, an email address can be used to authenticate users (see `GitGud.Auth.check_credentials/2`)
  and resolve Git commit authors.
  """

  use Ecto.Schema

  alias GitGud.DB
  alias GitGud.User

  alias Ecto.Multi

  import Ecto.Query, only: [from: 2]
  import Ecto.Changeset

  schema "emails" do
    belongs_to :user, User
    field :address, :string
    field :verified, :boolean, default: false
    timestamps(updated_at: false)
    field :verified_at, :naive_datetime
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

  This function validates the given `params` using `registration_changeset/2`.
  """
  @spec create(map|keyword) :: {:ok, t} | {:error, Ecto.Changeset.t}
  def create(params) do
    DB.insert(registration_changeset(%__MODULE__{}, Map.new(params)))
  end

  @doc """
  Similar to `create/1`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec create!(map|keyword) :: t
  def create!(params) do
    DB.insert!(registration_changeset(%__MODULE__{}, Map.new(params)))
  end

  @doc """
  Verifies the given `email`.
  """
  @spec verify(t) :: {:ok, t} | {:error, Ecto.Changeset.t}
  def verify(%__MODULE__{} = email) do
    case DB.transaction(verify_email_consistency(email)) do
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
  Returns an email registration changeset for the given `params`.
  """
  @spec registration_changeset(t, map) :: Ecto.Changeset.t
  def registration_changeset(%__MODULE__{} = email, params \\ %{}) do
    email
    |> cast(params, [:user_id, :address])
    |> validate_required([:address])
    |> validate_format(:address, ~r/^([a-zA-Z0-9_\-\.]+)@([a-zA-Z0-9_\-\.]+)\.([a-zA-Z]{2,5})$/)
    |> assoc_constraint(:user)
    |> check_constraint(:address, name: :emails_address_constraint, message: "already taken")
    |> unique_constraint(:address, name: :emails_user_id_address_index)
  end

  @doc """
  Returns an email verification changeset for the given `params`.
  """
  @spec verification_changeset(t) :: Ecto.Changeset.t
  def verification_changeset(%__MODULE__{} = email) do
    email
    |> change(%{verified: true, verified_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)})
    |> check_constraint(:address, name: :emails_address_constraint, message: "already taken")
  end

  #
  # Helpers
  #

  defp verify_email_consistency(email) do
    Multi.new()
    |> Multi.update(:email, verification_changeset(email))
    |> Multi.delete_all(:unverified_emails, from(e in __MODULE__, where: e.verified == false and e.address == ^email.address))
    |> Multi.run(:user, &fetch_user/2)
    |> Multi.run(:user_with_primary_email, &update_user_primary_email/2)
  end

  defp fetch_user(db, %{email: email}) do
    {:ok, db.get!(User, email.user_id)}
  end

  defp update_user_primary_email(db, %{user: user, email: email}) do
    unless user.primary_email_id,
      do: db.update(User.email_changeset(user, :primary_email, email)),
    else: {:ok, user}
  end
end
