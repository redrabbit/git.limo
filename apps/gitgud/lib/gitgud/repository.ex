defmodule GitGud.Repository do
  use Ecto.Schema

  import Ecto.Changeset

  schema "repositories" do
    belongs_to  :owner,       GitGud.User
    field       :path,        :string
    field       :name,        :string
    field       :description, :string
    timestamps()
  end

  @type t :: %__MODULE__{
    id: pos_integer,
    owner_id: pos_integer,
    owner: GitGud.User.t,
    path: binary,
    name: binary,
    description: binary,
    inserted_at: NaiveDateTime.t,
    updated_at: NaiveDateTime.t,
  }

  @spec changeset(t, map) :: Ecto.Changeset.t
  def changeset(%__MODULE__{} = user, params \\ %{}) do
    user
    |> cast(params, [:user_id, :path, :name, :description])
    |> validate_required([:user_id, :path, :name])
    |> validate_format(:path, ~r/^[a-zA-Z0-9_-]+$/)
    |> validate_length(:name, min: 3, max: 80)
    |> unique_constraint(:path)
    |> assoc_constraint(:user)
  end
end
