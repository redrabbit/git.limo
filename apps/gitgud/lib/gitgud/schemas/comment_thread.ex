defmodule GitGud.CommentThread do
  @moduledoc """
  Comment-thread schema and helper functions.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  alias GitGud.DB

  alias GitGud.Comment
  alias GitGud.User

  schema "comment_threads" do
    belongs_to :user, User
    has_many :comments, Comment, foreign_key: :thread_id
    field :locked, :boolean, default: false
    timestamps()
  end

  @type t :: %__MODULE__{
    id: pos_integer,
    user_id: pos_integer,
    user: User.t,
    comments: [Comment.t],
    locked: boolean,
    inserted_at: NaiveDateTime.t,
    updated_at: NaiveDateTime.t
  }

  @doc """
  Returns a comment thread changeset for the given `params`.
  """
  @spec changeset(t, map) :: Ecto.Changeset.t
  def changeset(%__MODULE__{} = comment_thread, params \\ %{}) do
    comment_thread
    |> cast(params, [:user_id, :locked])
    |> validate_required([:user_id])
    |> assoc_constraint(:user)
  end
end
