defmodule GitGud.GitCommit.Review do
  @moduledoc """
  Git commit review schema and helper functions.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias GitGud.Comment
  alias GitGud.Repo

  schema "git_commit_reviews" do
    belongs_to :repo, Repo
    many_to_many :comments, Comment, join_through: "git_commit_reviews_comments", join_keys: [review_id: :id, comment_id: :id]
    field :oid, :binary
    field :blob_oid, :binary
    field :hunk, :integer
    field :line, :integer
    timestamps()
  end

  @type t :: %__MODULE__{
    id: pos_integer,
    repo_id: pos_integer,
    repo: Repo.t,
    comments: [Comment.t],
    oid: GitRekt.Git.oid,
    blob_oid: GitRekt.Git.oid,
    hunk: non_neg_integer,
    line: non_neg_integer,
    inserted_at: NaiveDateTime.t,
    updated_at: NaiveDateTime.t
  }

  @doc """
  Returns a commit review changeset for the given `params`.
  """
  @spec changeset(t, map) :: Ecto.Changeset.t
  def changeset(%__MODULE__{} = commit_comment, params \\ %{}) do
    commit_comment
    |> cast(params, [:repo_id, :oid, :blob_oid, :hunk, :line])
    |> cast_assoc(:comments, required: true, with: &Comment.changeset/2)
    |> validate_required([:repo_id, :oid, :blob_oid, :hunk, :line])
    |> assoc_constraint(:repo)
  end
end
