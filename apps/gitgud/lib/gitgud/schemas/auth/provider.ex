defmodule GitGud.Auth.Provider do
  @moduledoc """
  Authentication provider schema and helper functions.
  """

  use Ecto.Schema

  alias GitGud.Auth

  import Ecto.Changeset

  schema "users_authentications_providers" do
    belongs_to :auth, Auth
    field :provider, :string
    field :provider_id, :integer
    field :token, :string
    timestamps()
  end

  @type t :: %__MODULE__{
    id: pos_integer,
    auth_id: pos_integer,
    auth: Auth.t,
    provider: binary,
    provider_id: pos_integer,
    token: binary,
    inserted_at: NaiveDateTime.t,
    updated_at: NaiveDateTime.t
  }

  @doc """
  Returns an authentication provider changeset for the given `params`.
  """
  @spec changeset(t, map) :: Ecto.Changeset.t
  def changeset(%__MODULE__{} = provider, params \\ %{}) do
    provider
    |> cast(params, [:auth_id, :provider, :provider_id, :token])
    |> validate_required([:provider, :provider_id, :token])
    |> assoc_constraint(:auth)
  end
end

