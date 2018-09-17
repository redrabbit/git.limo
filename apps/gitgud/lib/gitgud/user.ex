defmodule GitGud.User do
  @moduledoc """
  User account schema and helper functions.
  """

  use Ecto.Schema

  import Ecto, only: [build_assoc: 2]
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  import Comeonin.Argon2, only: [add_hash: 1, check_pass: 2]

  alias GitGud.DB

  alias GitGud.Repo
  alias GitGud.SSHAuthenticationKey

  schema "users" do
    field     :username,             :string
    field     :name,                 :string
    field     :email,                :string
    has_many  :repositories,         Repo, foreign_key: :owner_id
    has_many  :authentication_keys,  SSHAuthenticationKey
    field     :password,             :string, virtual: true
    field     :password_hash,        :string
    timestamps()
  end

  @type t :: %__MODULE__{
    id: pos_integer,
    username: binary,
    name: binary,
    email: binary,
    repositories: [Repo.t],
    authentication_keys: [SSHAuthenticationKey.t],
    password: binary,
    password_hash: binary,
    inserted_at: NaiveDateTime.t,
    updated_at: NaiveDateTime.t
  }

  @doc """
  Creates a new user with the given `params`.
  """
  @spec register(map|keyword) :: {:ok, t} | {:error, Ecto.Changeset.t}
  def register(params) do
    params
    |> Map.new()
    |> registration_changeset()
    |> DB.insert()
  end

  @doc """
  Similar to `register/1`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec register!(map|keyword) :: t
  def register!(params) do
    case register(params) do
      {:ok, user} -> user
      {:error, changeset} -> raise Ecto.InvalidChangesetError, action: changeset.action, changeset: changeset
    end
  end

  @doc """
  Returns a user changeset for the given `params`.
  """
  @spec registration_changeset(map) :: Ecto.Changeset.t
  def registration_changeset(params \\ %{}) do
    %__MODULE__{}
    |> cast(params, [:username, :name, :email, :password])
    |> validate_required([:username, :email, :password])
    |> validate_length(:username, min: 3, max: 20)
    |> validate_format(:username, ~r/^[a-zA-Z0-9_-]+$/)
    |> validate_format(:email, ~r/@/)
    |> validate_length(:password, min: 6)
    |> put_password_hash(:password)
    |> unique_constraint(:username)
    |> unique_constraint(:email)
  end

  @doc """
  Puts the given SSH `key` to the `user`'s authentication keys.
  """
  @spec put_ssh_key(t, binary) :: {:ok, SSHAuthenticationKey.t} | {:error, Ecto.Changeset.t}
  def put_ssh_key(%__MODULE__{} = user, key) do
    user
    |> build_assoc(:authentication_keys)
    |> struct(key: key)
    |> DB.insert()
  end

  @doc """
  Returns the matching user for the given credentials; elsewhise returns `nil`.
  """
  @spec check_credentials(binary, binary) :: t | nil
  def check_credentials(email_or_username, password) do
    user = DB.one(from u in __MODULE__, where: u.email == ^email_or_username or u.username == ^email_or_username)
    case check_pass(user, password) do
      {:ok, user} -> user
      {:error, _reason} -> nil
    end
  end

  #
  # Helpers
  #

  defp put_password_hash(changeset, field) do
    if password = changeset.valid? && get_field(changeset, field),
      do: change(changeset, add_hash(password)),
    else: changeset
  end
end
