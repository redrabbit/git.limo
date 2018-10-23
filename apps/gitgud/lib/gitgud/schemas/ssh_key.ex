defmodule GitGud.SSHKey do
  @moduledoc """
  Secure Shell (SSH) authentication key schema.
  """

  use Ecto.Schema

  alias GitGud.DB
  alias GitGud.User

  import Ecto.Changeset

  schema "ssh_authentication_keys" do
    belongs_to :user, User
    field      :name, :string
    field      :data, :string, virtual: true
    field      :fingerprint, :string
    timestamps()
  end

  @type t :: %__MODULE__{
    id: pos_integer,
    user_id: pos_integer,
    user: User.t,
    name: binary,
    data: binary,
    fingerprint: binary,
    inserted_at: NaiveDateTime.t,
    updated_at: NaiveDateTime.t
  }

  @doc """
  Creates a new SSH key with the given `params`.
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
  Returns a SSH key changeset for the given `params`.
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
