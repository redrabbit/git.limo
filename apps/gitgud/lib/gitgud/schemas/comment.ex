defmodule GitGud.Comment do
  @moduledoc """
  Comment schema and helper functions.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  alias GitGud.DB

  alias GitGud.CommentThread
  alias GitGud.User

  schema "comments" do
    belongs_to :thread, CommentThread
    belongs_to :parent, __MODULE__
    has_many :children, __MODULE__, foreign_key: :parent_id
    belongs_to :user, User
    field :body, :string
    timestamps()
  end

  @type t :: %__MODULE__{
    id: pos_integer,
    thread_id: pos_integer,
    thread: CommentThread.t,
    parent_id: pos_integer | nil,
    parent: t | nil,
    children: [t],
    user_id: pos_integer,
    user: User.t,
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
    |> cast(params, [:thread_id, :parent_id, :user_id, :body])
    |> validate_required([:thread_id, :user_id, :body])
    |> assoc_constraint(:thread)
    |> assoc_constraint(:parent)
    |> assoc_constraint(:user)
  end
end
