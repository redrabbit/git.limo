defmodule GitGud.User do
  @moduledoc """
  User account schema and helper functions.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Ecto.Multi

  alias GitGud.DB

  alias GitGud.Account
  alias GitGud.Email
  alias GitGud.Repo
  alias GitGud.SSHKey
  alias GitGud.GPGKey

  schema "users" do
    field :login, :string
    field :name, :string
    has_one :account, Account, on_replace: :update, on_delete: :delete_all
    belongs_to :primary_email, Email, on_replace: :update
    belongs_to :public_email, Email, on_replace: :update
    has_many :emails, Email, on_delete: :delete_all
    has_many :repos, Repo, on_delete: :delete_all, foreign_key: :owner_id
    field :bio, :string
    field :location, :string
    field :website_url, :string
    field :avatar_url, :string
    has_many :ssh_keys, SSHKey, on_delete: :delete_all
    has_many :gpg_keys, GPGKey, on_delete: :delete_all
    timestamps()
  end

  @type t :: %__MODULE__{
    id: pos_integer,
    login: binary,
    name: binary,
    account: Account.t,
    primary_email: Email.t,
    public_email: Email.t,
    emails: [Email.t],
    repos: [Repo.t],
    bio: binary,
    location: binary,
    website_url: binary,
    avatar_url: binary,
    ssh_keys: [SSHKey.t],
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
      %{address: "m.flach@almightycouch.com"}
    ],
    account: %{
      password: "qwertz"
    }
  )
  ```
  This function validates the given `params` using `registration_changeset/2`.
  """
  @spec create(map|keyword) :: {:ok, t} | {:error, Ecto.Changeset.t}
  def create(params) do
    case create_with_primary_email(registration_changeset(%__MODULE__{}, Map.new(params))) do
      {:ok, %{user: user}} ->
        {:ok, put_in(user.account.password, nil)}
      {:error, _name, changeset, _changes} ->
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
  Updates the given `user` with the given `changeset_type` and `params`.

  ```elixir
  {:ok, user} = GitGud.User.update(user, :profile, name: "Mario Bros")
  ```

  Following changeset types are available:

  * `:profile` -- see `profile_changeset/2`.
  * `:password` -- see `password_changeset/2`.
  * `:oauth2` -- see `oauth2_changeset/2`.

  This function can also be used to update email associations, for example:

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
  Returns `true` is `user` is verified; otherwise returns `false`.
  """
  @spec verified?(t) :: boolean
  def verified?(%__MODULE__{} = user), do: !!user.primary_email_id
  def verified?(nil), do: false

  @doc """
  Returns a registration changeset for the given `params`.
  """
  @spec registration_changeset(t, map) :: Ecto.Changeset.t
  def registration_changeset(%__MODULE__{} = user, params \\ %{}) do
    user
    |> cast(params, [:login, :name, :bio, :website_url, :location])
    |> cast_assoc(:account, required: true, with: &Account.registration_changeset/2)
    |> cast_assoc(:emails, required: true, with: &Email.registration_changeset/2)
    |> validate_required([:login, :name])
    |> validate_login()
    |> verify_oauth2_email()
    |> validate_url(:website_url)
    |> validate_url(:avatar_url)
  end

  @doc """
  Returns a profile changeset for the given `params`.
  """
  @spec profile_changeset(t, map) :: Ecto.Changeset.t
  def profile_changeset(%__MODULE__{} = user, params \\ %{}) do
    user
    |> cast(params, [:name, :public_email_id, :bio, :location, :website_url, :avatar_url])
    |> validate_required([:name])
    |> assoc_constraint(:public_email)
    |> validate_url(:website_url)
    |> validate_url(:avatar_url)
  end

  @doc """
  Returns an email changeset for the given `email`.
  """
  @spec email_changeset(t, :primary_email | :public_email, Email.t) :: Ecto.Changeset.t
  def email_changeset(%__MODULE__{} = user, :primary_email, email) do
    user
    |> struct(primary_email: nil)
    |> change(avatar_url: gravatar_url(email))
    |> put_assoc(:primary_email, email)
  end

  def email_changeset(%__MODULE__{} = user, :public_email, email) do
    user
    |> struct(public_email: nil)
    |> change()
    |> put_assoc(:public_email, email)
  end

  @doc """
  Returns a password changeset for the given `params`.
  """
  @spec password_changeset(t, map) :: Ecto.Changeset.t
  def password_changeset(%__MODULE__{} = user, params \\ %{}) do
    user
    |> cast(%{account: params}, [])
    |> cast_assoc(:account, required: true, with: &Account.password_changeset/2)
  end

  @doc """
  Returns an OAuth2.0 changeset for the given `params`.
  """
  @spec oauth2_changeset(t, map) :: Ecto.Changeset.t
  def oauth2_changeset(%__MODULE__{} = user, params \\ %{}) do
    user
    |> cast(%{account: params}, [])
    |> cast_assoc(:account, required: true, with: &Account.oauth2_changeset/2)
  end

  #
  # Helpers
  #

  defp create_with_primary_email(changeset) do
    Multi.new()
    |> Multi.insert(:user_, changeset)
    |> Multi.run(:user, &set_verified_primary_email/2)
    |> DB.transaction()
  end

  defp set_verified_primary_email(db, %{user_: user}) do
    if email = Enum.find(user.emails, &(&1.verified)),
      do: db.update(update_changeset(user, :primary_email, email)),
    else: {:ok, user}
  end

  defp update_changeset(user, :profile, params), do: profile_changeset(user, Map.new(params))
  defp update_changeset(user, :password, params), do: password_changeset(user, Map.new(params))
  defp update_changeset(user, :oauth2, params), do: oauth2_changeset(user, Map.new(params))
  defp update_changeset(user, changeset_type, %Email{verified: true} = email) when changeset_type in [:primary_email, :public_email], do: email_changeset(user, changeset_type, email)

  defp validate_login(changeset) do
    changeset
    |> validate_length(:login, min: 3, max: 24)
    |> validate_format(:login, ~r/^[a-zA-Z0-9_-]+$/)
    |> validate_exclusion(:login, ["auth", "login", "logout", "graphql", "new", "password", "register", "settings"])
    |> unique_constraint(:login)
  end

  defp validate_url(changeset, field) do
    if url = get_change(changeset, field) do
      case URI.parse(url) do
        %URI{scheme: nil} ->
          add_error(changeset, field, "invalid")
        %URI{host: nil} ->
          add_error(changeset, field, "invalid")
        %URI{} ->
          changeset
      end
    end || changeset
  end

  defp verify_oauth2_email(changeset) do
    if auth_changeset = get_change(changeset, :account) do
      emails = get_change(changeset, :emails, [])
      if email_changeset = !Enum.empty?(emails) && hd(emails) do
        providers = get_change(auth_changeset, :oauth2_providers)
        if provider_changeset = is_list(providers) && providers != [] && hd(providers) do
          case Phoenix.Token.verify(GitGud.Web.Endpoint, get_change(provider_changeset, :token), provider_changeset.params["email_token"]) do
            {:ok, email_address} ->
              if email_address == get_change(email_changeset, :address) do
                put_change(changeset, :emails, Enum.map(emails, &merge(&1, Email.verification_changeset(&1.data))))
              end
            {:error, _reason} ->
              nil
          end
        end
      end
    end || changeset
  end

  defp gravatar_url(email) do
    %URI{}
    |> gravatar_base_url()
    |> gravatar_email(email)
    |> to_string()
  end

  defp gravatar_base_url(uri), do: %URI{uri|scheme: "https", host: "secure.gravatar.com", path: "/avatar"}
  defp gravatar_email(uri, email), do: %URI{uri|path: Path.join(uri.path, Base.encode16(:crypto.hash(:md5, String.downcase(email.address)), case: :lower))}
end
