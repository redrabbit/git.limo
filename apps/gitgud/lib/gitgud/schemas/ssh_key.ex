defmodule GitGud.SSHKey do
  @moduledoc """
  Secure Shell (SSH) authentication key schema and helper functions.

  An `GitGud.SSHKey` is used to authenticate users via *Public Key Authentication* in `GitGud.SSHServer`.
  """

  use Ecto.Schema

  alias GitGud.DB
  alias GitGud.User

  import Ecto.Changeset

  schema "users_ssh_keys" do
    belongs_to :user, User
    field      :name, :string
    field      :data, :string, virtual: true
    field      :fingerprint, :string
    timestamps(updated_at: false)
    field      :last_used_at, :naive_datetime
  end

  @type t :: %__MODULE__{
    id: pos_integer,
    user_id: pos_integer,
    user: User.t,
    name: binary,
    data: binary,
    fingerprint: binary,
    inserted_at: NaiveDateTime.t,
    last_used_at: NaiveDateTime.t
  }

  @doc """
  Creates a new SSH key with the given `params`.

  ```elixir
  {:ok, ssh_key} = GitGud.SSHKey.create(user_id: user.id, name: "My SSH Key", data: "ssh-rsa AAAAB3NzaC1yc2...")
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
  Deletes the given `ssh_key`.
  """
  @spec delete(t) :: {:ok, t} | {:error, Ecto.Changeset.t}
  def delete(%__MODULE__{} = ssh_key) do
    DB.delete(ssh_key)
  end

  @doc """
  Similar to `delete!/1`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec delete!(t) :: t
  def delete!(%__MODULE__{} = ssh_key) do
    DB.delete!(ssh_key)
  end

  def update_timestamp(%__MODULE__{} = ssh_key) do
    DB.update(change(ssh_key, %{last_used_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)}))
  end

  def update_timestamp!(%__MODULE__{} = ssh_key) do
    DB.update!(change(ssh_key, %{last_used_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)}))
  end

  @doc """
  Returns a SSH key changeset for the given `params`.

  If `:name` is omitted and the given public key contains a comment, the comment will be used as `:name`.

  This function computes (see `:public_key.ssh_decode/2` and `:public_key.ssh_hostkey_fingerprint/1`)
  and stores a fingerprint of the public key. It does not save the given `:data` into the database.
  """
  @spec changeset(t, map) :: Ecto.Changeset.t
  def changeset(%__MODULE__{} = ssh_key, params \\ %{}) do
    ssh_key
    |> cast(params, [:user_id, :name, :data])
    |> validate_required([:user_id, :data])
    |> put_fingerprint()
    |> assoc_constraint(:user)
  end

  #
  # Helpers
  #

  defp put_fingerprint(changeset) do
    if data = changeset.valid? && get_change(changeset, :data) do
      try do
        [{key, attrs}] = :public_key.ssh_decode(data, :public_key)
        fingerprint = :public_key.ssh_hostkey_fingerprint(key)
        changeset = put_change(changeset, :fingerprint, to_string(fingerprint))
        if comment = !get_field(changeset, :name) && Keyword.get(attrs, :comment),
          do: put_change(changeset, :name, to_string(comment)),
        else: changeset
      rescue
        _ ->
          add_error(changeset, :data, "invalid")
      end
    end || changeset
  end
end
