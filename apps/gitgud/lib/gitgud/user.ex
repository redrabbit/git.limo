defmodule GitGud.User do
  use Ecto.Schema

  import Ecto.Changeset

  schema "users" do
    field :username,  :string
    field :name,      :string
    field :email,     :string
    timestamps()
  end

  @type t :: %__MODULE__{
    id: pos_integer,
    username: binary,
    name: binary,
    email: binary,
    inserted_at: NaiveDateTime.t,
    updated_at: NaiveDateTime.t
  }

  @spec changeset(t, map) :: Ecto.Changeset.t
  def changeset(%__MODULE__{} = user, params \\ %{}) do
    user
    |> cast(params, [:username, :name, :email])
    |> validate_required([:username, :email])
    |> validate_length(:username, min: 3, max: 20)
    |> validate_format(:username, ~r/^[a-zA-Z0-9_-]+$/)
    |> validate_format(:email, ~r/@/)
    |> unique_constraint(:username)
    |> unique_constraint(:email)
  end
end
