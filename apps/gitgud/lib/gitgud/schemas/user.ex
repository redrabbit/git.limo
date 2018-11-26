defmodule GitGud.User do
  @moduledoc """
  User account schema and helper functions.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  import Comeonin.Argon2, only: [add_hash: 1, check_pass: 2]

  alias GitGud.DB

  alias GitGud.Email
  alias GitGud.Repo
  alias GitGud.SSHKey

  schema "users" do
    field       :login,         :string
    field       :name,          :string
    belongs_to  :primary_email, Email, on_replace: :update
    belongs_to  :public_email,  Email, on_replace: :update
    field       :bio,           :string
    field       :url,           :string
    field       :location,      :string
    has_many    :emails,        Email, on_delete: :delete_all
    has_many    :repos,         Repo, foreign_key: :owner_id
    has_many    :ssh_keys,      SSHKey, on_delete: :delete_all
    field       :password,      :string, virtual: true
    field       :password_hash, :string
    timestamps()
  end

  @type t :: %__MODULE__{
    id: pos_integer,
    login: binary,
    name: binary,
    primary_email: Email.t,
    public_email: Email.t,
    bio: binary,
    url: binary,
    location: binary,
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

  ```elixir
  {:ok, user} = GitGud.User.create(
    login: "redrabbit",
    name: "Mario Flach",
    emails: [
      %{email: "m.flach@almightycouch.com"}
    ],
    password: "qwertz"
  )
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
  Updates the given `user` with the given `changeset_type` and `params`.

  ```elixir
  {:ok, user} = GitGud.User.update(user, :profile, name: "Mario Bros")
  ```

  Following changeset types are available:

  * `:profile` -- see `profile_changeset/2`.
  * `:password` -- see `password_changeset/2`.

  This function can also be used to update associations, for example:

  ```elixir
  {:ok, user} = GitGud.User.update(user, :primary_email, email)
  ```
  """
  @spec update(t, atom, map|keyword) :: {:ok, t} | {:error, Ecto.Changeset.t}
  @spec update(t, atom, struct) :: {:ok, t} | {:error, Ecto.Changeset.t}
  def update(%__MODULE__{} = user, changeset_type, params) do
    DB.update(update_changeset(user, changeset_type, params))
  end

  @doc """
  Similar to `update/3`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec update!(t, atom, map|keyword) :: t
  @spec update!(t, atom, struct) :: {:ok, t} | {:error, Ecto.Changeset.t}
  def update!(%__MODULE__{} = user, changeset_type, params) do
    DB.update!(update_changeset(user, changeset_type, params))
  end

  @doc """
  Deletes the given `user`.

  User associations (emails, repositories, etc.) will automatically be deleted.
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
    |> cast(params, [:login, :name, :bio, :url, :location, :password])
    |> cast_assoc(:emails, required: true)
    |> validate_required([:login, :name, :password])
    |> validate_login()
    |> validate_url()
    |> validate_password()
  end

  @doc """
  Returns a profile changeset for the given `params`.
  """
  @spec profile_changeset(map) :: Ecto.Changeset.t
  def profile_changeset(%__MODULE__{} = user, params \\ %{}) do
    user
    |> cast(params, [:name, :public_email_id, :bio, :url, :location])
    |> assoc_constraint(:public_email)
    |> validate_url()
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

  ```elixir
  if user = GitGud.User.check_credentials("redrabbit", "qwertz") do
    IO.puts "Welcome!"
  else
    IO.puts "Invalid login credentials."
  end
  ```
  """
  @spec check_credentials(binary, binary) :: t | nil
  def check_credentials(email_or_login, password) do
    query = from u in __MODULE__,
           join: e in assoc(u, :emails),
       or_where: u.login == ^email_or_login,
       or_where: e.address == ^email_or_login and e.verified == true,
        preload: [emails: e]
    case check_pass(DB.one(query), password) do
      {:ok, user} -> user
      {:error, _reason} -> nil
    end
  end

  #
  # Helpers
  #

  defp update_changeset(user, :profile, params), do: profile_changeset(user, Map.new(params))
  defp update_changeset(user, :password, params), do: password_changeset(user, Map.new(params))
  defp update_changeset(user, field, value) when field in [:primary_email, :public_email] do
    user
    |> struct([{field, nil}])
    |> change()
    |> put_assoc(field, value)
  end

  defp validate_login(changeset) do
    changeset
    |> validate_length(:login, min: 3, max: 24)
    |> validate_format(:login, ~r/^[a-zA-Z0-9_-]+$/)
    |> unique_constraint(:login)
  end

  def validate_url(changeset) do
    if url = get_change(changeset, :url) do
      case URI.parse(url) do
        %URI{scheme: nil} ->
          add_error(changeset, :url, "invalid")
        %URI{host: nil} ->
          add_error(changeset, :url, "invalid")
        %URI{} ->
          changeset
      end
    end || changeset
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
