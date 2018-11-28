defmodule GitGud.Auth do
  @moduledoc """
  Authentication schema and helper functions.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  alias GitGud.DB

  alias GitGud.User

  alias GitGud.Auth.Provider

  import Comeonin.Argon2, only: [add_hash: 1, check_pass: 2, checkpw: 2]

  schema "users_authentications" do
    belongs_to :user, User
    has_many :providers, Provider
    field :password, :string, virtual: true
    field :password_hash, :string
    timestamps()
  end

  @type t :: %__MODULE__{
    id: pos_integer,
    user_id: pos_integer,
    user: User.t,
    providers: [Provider.t],
    password: binary,
    password_hash: binary,
    inserted_at: NaiveDateTime.t,
    updated_at: NaiveDateTime.t
  }

  @doc """
  Returns the matching user for the given credentials; elsewhise returns `nil`.

  ```elixir
  if user = GitGud.Auth.check_credentials("redrabbit", "qwertz") do
    IO.puts "Welcome!"
  else
    IO.puts "Invalid login credentials."
  end
  ```
  """
  @spec check_credentials(binary, binary) :: t | nil
  def check_credentials(email_or_login, password) do
    query = from u in User,
           join: a in assoc(u, :auth),
           join: e in assoc(u, :emails),
       or_where: u.login == ^email_or_login,
       or_where: e.address == ^email_or_login and e.verified == true,
        preload: [auth: a, emails: e]
    user = DB.one(query)
    if user && checkpw(password, user.auth.password_hash), do: user
  end

  @doc """
  Returns a registration changeset for the given `params`.
  """
  @spec registration_changeset(t, map) :: Ecto.Changeset.t
  def registration_changeset(%__MODULE__{} = auth, params \\ %{}) do
    auth
    |> cast(params, [:user_id, :password])
    |> cast_assoc(:providers)
    |> validate_required([:password])
    |> validate_password()
    |> assoc_constraint(:user)
  end

  @doc """
  Returns a password changeset for the given `params`.
  """
  @spec password_changeset(t, map) :: Ecto.Changeset.t
  def password_changeset(%__MODULE__{} = auth, params \\ %{}) do
    auth
    |> cast(params, [:user_id, :password])
    |> validate_required([:password])
    |> validate_old_password()
    |> validate_password()
    |> assoc_constraint(:user)
  end

  #
  # Helpers
  #

  defp validate_password(changeset) do
    changeset
    |> validate_length(:password, min: 6)
    |> validate_confirmation(:password)
    |> put_password_hash(:password)
  end

  defp validate_old_password(%{data: data, params: params} = changeset) do
    error_param = "old_password"
    error_field = String.to_atom(error_param)
    errors =
      case Map.get(params, error_param) do
        value when is_nil(value) or value == "" ->
          [{error_field, {"can't be blank", [validation: :required]}}]
        value ->
          case check_pass(data, value) do
            {:ok, _user} -> []
            {:error, _reason} -> [{error_field, {"does not match old password", [validation: :old_password]}}]
          end
      end
    %{changeset|validations: [{:old_password, []}|changeset.validations], errors: errors ++ changeset.errors, valid?: changeset.valid? and errors == []}
  end

  defp put_password_hash(changeset, field) do
    if password = changeset.valid? && get_field(changeset, field),
      do: change(changeset, add_hash(password)),
    else: changeset
  end
end
