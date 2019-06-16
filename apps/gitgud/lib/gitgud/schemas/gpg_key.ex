defmodule GitGud.GPGKey do
  @moduledoc """
  GNU Privacy Guard (GPG) key schema and helper functions.
  """

  use Ecto.Schema

  alias GitGud.DB
  alias GitGud.User

  import Ecto.Changeset

  schema "gpg_keys" do
    belongs_to :user, User
    field :data, :string, virtual: true
    field :key_id, :binary
    timestamps(updated_at: false)
  end

  @type t :: %__MODULE__{
    id: pos_integer,
    user_id: pos_integer,
    user: User.t,
    data: binary,
    key_id: binary,
    inserted_at: NaiveDateTime.t,
  }

  @doc """
  Creates a new SSH key with the given `params`.

  ```elixir
  {:ok, gpg_key} = GitGud.GPGKey.create(user_id: user.id, data: "...")
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
  Deletes the given `gpg_key`.
  """
  @spec delete(t) :: {:ok, t} | {:error, Ecto.Changeset.t}
  def delete(%__MODULE__{} = gpg_key) do
    DB.delete(gpg_key)
  end

  @doc """
  Similar to `delete!/1`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec delete!(t) :: t
  def delete!(%__MODULE__{} = gpg_key) do
    DB.delete!(gpg_key)
  end

  @doc """
  Returns a GPG key changeset for the given `params`.
  """
  @spec changeset(t, map) :: Ecto.Changeset.t
  def changeset(%__MODULE__{} = gpg_key, params \\ %{}) do
    gpg_key
    |> cast(params, [:user_id, :data])
    |> validate_required([:user_id, :data])
    |> put_key_id()
    |> unique_constraint(:key_id, name: :gpg_keys_user_id_key_id_index)
    |> assoc_constraint(:user)
  end

  #
  # Helpers
  #

  defp put_key_id(changeset) do
    if _data = changeset.valid? && get_change(changeset, :data),
     do: put_change(changeset, :key_id, Base.decode16!("FFFFFFFFFFFFFFFF")),
   else: changeset
  end
end
