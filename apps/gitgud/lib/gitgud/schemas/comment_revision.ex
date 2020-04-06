defmodule GitGud.CommentRevision do
  @moduledoc """
  Comment revision schema for keeping track of comment updates.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias GitGud.DB
  alias GitGud.Comment
  alias GitGud.User

  schema "comment_revisions" do
    belongs_to :comment, Comment
    belongs_to :author, User
    field :body, :string
    timestamps(updated_at: false)
  end

  @type t :: %__MODULE__{
    id: pos_integer,
    comment_id: pos_integer,
    comment: Comment.t,
    author_id: pos_integer,
    author: User.t,
    body: binary,
    inserted_at: NaiveDateTime.t,
  }
end
