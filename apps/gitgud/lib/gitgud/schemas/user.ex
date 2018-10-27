defmodule GitGud.User do
  @moduledoc """
  User account schema and helper functions.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  import Comeonin.Argon2, only: [add_hash: 1, check_pass: 2]

  alias Ecto.Multi

  alias GitGud.DB

  alias GitGud.Email
  alias GitGud.Repo
  alias GitGud.SSHKey

  schema "users" do
    field       :username,      :string
    field       :name,          :string
    belongs_to  :primary_email, Email
    has_many    :emails,        Email, on_delete: :delete_all
    has_many    :repos,         Repo, foreign_key: :owner_id
    has_many    :ssh_keys,      SSHKey, on_delete: :delete_all
    field       :password,      :string, virtual: true
    field       :password_hash, :string
    timestamps()
  end

  @type t :: %__MODULE__{
    id: pos_integer,
    username: binary,
    name: binary,
    primary_email: Email.t,
    emails: [Email.t],
    repos: [Repo.t],
    ssh_keys: [SSHKey.t],
    password: binary,
    password_hash: binary,
    inserted_at: NaiveDateTime.t,
    updated_at: NaiveDateTime.t
  }

  @doc """
  Creates a new user with the given `params`.
  """
  @spec create(map|keyword) :: {:ok, t} | {:error, Ecto.Changeset.t}
  def create(params) do
    case create_user_with_primary_email(params) do
      {:ok, multi} ->
        {:ok, multi.user_with_primary_email}
      {:error, _multi_name, changeset, _changes} ->
        {:error, changeset}
    end
  end

  @doc """
  Similar to `create/1`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec create!(map|keyword) :: t
  def create!(params) do
    case create(params) do
      {:ok, user} -> user
      {:error, changeset} -> raise Ecto.InvalidChangesetError, action: changeset.action, changeset: changeset
    end
  end

  @doc """
  Updates the given `user` with the given `params`.
  """
  @spec update(t, atom, map|keyword) :: {:ok, t} | {:error, Ecto.Changeset.t}
  def update(%__MODULE__{} = user, changeset_type, params) do
    DB.update(update_changeset(user, changeset_type, Map.new(params)))
  end

  @doc """
  Similar to `update/2`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec update!(t, atom, map|keyword) :: t
  def update!(%__MODULE__{} = user, changeset_type, params) do
    DB.update!(update_changeset(user, changeset_type, Map.new(params)))
  end

  @doc """
  Deletes the given `user`.
  """
  @spec delete(t) :: {:ok, t} | {:error, Ecto.Changeset.t}
  def delete(%__MODULE__{} = user) do
    DB.delete(user)
  end

  @doc """
  Similar to `delete!/1`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec delete!(t) :: t
  def delete!(%__MODULE__{} = user) do
    DB.delete!(user)
  end

  @doc """
  Returns a registration changeset for the given `params`.
  """
  @spec registration_changeset(t, map) :: Ecto.Changeset.t
  def registration_changeset(%__MODULE__{} = user, params \\ %{}) do
    user
    |> cast(params, [:username, :name, :password])
    |> cast_assoc(:emails, required: true)
    |> validate_required([:username, :name, :password])
    |> validate_username()
    |> validate_password()
  end

  @doc """
  Returns a profile changeset for the given `params`.
  """
  @spec profile_changeset(map) :: Ecto.Changeset.t
  def profile_changeset(%__MODULE__{} = user, params \\ %{}) do
    user
    |> cast(params, [:name])
    |> validate_required([:name])
  end

  @doc """
  Returns a password changeset for the given `params`.
  """
  @spec password_changeset(map) :: Ecto.Changeset.t
  def password_changeset(%__MODULE__{} = user, params \\ %{}) do
    user
    |> cast(params, [:password])
    |> validate_required([:password])
    |> validate_old_password()
    |> validate_password()
  end

  @doc """
  Returns the matching user for the given credentials; elsewhise returns `nil`.
  """
  @spec check_credentials(binary, binary) :: t | nil
  def check_credentials(email_or_username, password) do
    query = from u in __MODULE__,
           join: e in assoc(u, :emails),
       or_where: u.username == ^email_or_username,
       or_where: e.verified == true and e.email == ^email_or_username,
        preload: [emails: e]
    case check_pass(DB.one(query), password) do
      {:ok, user} -> user
      {:error, _reason} -> nil
    end
  end

  #
  # Helpers
  #

  defp create_user_with_primary_email(params) do
    Multi.new()
    |> Multi.insert(:user, registration_changeset(%__MODULE__{}, Map.new(params)))
    |> Multi.run(:user_with_primary_email, &create_primary_email/2)
    |> DB.transaction()
  end

  defp create_primary_email(db, %{user: user}) do
    user
    |> struct(primary_email: nil)
    |> change()
    |> put_assoc(:primary_email, hd(user.emails))
    |> db.update()
  end

  defp update_changeset(user, :profile, params), do: profile_changeset(user, params)
  defp update_changeset(user, :password, params), do: password_changeset(user, params)

  defp validate_username(changeset) do
    changeset
    |> validate_length(:username, min: 3, max: 24)
    |> validate_format(:username, ~r/^[a-zA-Z0-9_-]+$/)
    |> unique_constraint(:username)
  end

  defp validate_password(changeset) do
    changeset
    |> validate_length(:password, min: 6)
    |> validate_confirmation(:password)
    |> put_password_hash(:password)
  end

  defp validate_old_password(%{params: params} = changeset) do
    error_param = "old_password"
    error_field = String.to_atom(error_param)
    errors =
      case Map.get(params, error_param) do
        value when is_nil(value) or value == "" ->
          [{error_field, {"can't be blank", [validation: :required]}}]
        value ->
          case check_pass(changeset.data, value) do
            {:ok, _user} -> []
            {:error, _reason} -> [{error_field, {"does not match old password", [validation: :old_password]}}]
          end
      end
    %{changeset|validations: [{:old_password, []}|changeset.validations],
                errors: errors ++ changeset.errors,
                valid?: changeset.valid? and errors == []}
  end

  defp put_password_hash(changeset, field) do
    if password = changeset.valid? && get_field(changeset, field),
      do: change(changeset, add_hash(password)),
    else: changeset
  end
end
