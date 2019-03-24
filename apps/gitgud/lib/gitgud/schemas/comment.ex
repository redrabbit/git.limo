defmodule GitGud.Comment do
  @moduledoc """
  Comment schema and helper functions.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias GitGud.User

  schema "comments" do
    belongs_to :author, User
    belongs_to :parent, __MODULE__
    has_many :children, __MODULE__, foreign_key: :parent_id
    field :body, :string
    timestamps()
  end

  @type t :: %__MODULE__{
    id: pos_integer,
    author_id: pos_integer,
    author: User.t,
    parent_id: pos_integer | nil,
    parent: t | nil,
    children: [t],
    body: binary,
    inserted_at: NaiveDateTime.t,
    updated_at: NaiveDateTime.t
  }

  @doc """
  Returns a comment changeset for the given `params`.
  """
  @spec changeset(t, map) :: Ecto.Changeset.t
  def changeset(%__MODULE__{} = comment, params \\ %{}) do
    comment
    |> cast(params, [:author_id, :parent_id, :body])
    |> validate_required([:author_id, :body])
    |> assoc_constraint(:parent)
    |> assoc_constraint(:author)
  end
end
