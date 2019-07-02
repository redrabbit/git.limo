defmodule GitGud.CommitReview do
  @moduledoc """
  Git commit review schema and helper functions.
  """

  use Ecto.Schema

  alias Ecto.Multi

  alias GitRekt.Git

  alias GitGud.DB
  alias GitGud.Repo
  alias GitGud.Comment

  import Ecto.Changeset

  schema "commit_reviews" do
    belongs_to :repo, Repo
    many_to_many :comments, Comment, join_through: "commit_reviews_comments", join_keys: [review_id: :id, comment_id: :id]
    field :commit_oid, :binary
    timestamps()
  end

  @type t :: %__MODULE__{
    id: pos_integer,
    repo_id: pos_integer,
    repo: Repo.t,
    comments: [Comment.t],
    commit_oid: GitRekt.Git.oid,
    inserted_at: NaiveDateTime.t,
    updated_at: NaiveDateTime.t
  }


  @doc """
  Adds a new comment.
  """
  @spec add_comment(Repo.t, Git.oid, User.t, binary) :: {:ok, Comment.t} | {:error, term}
  def add_comment(repo, commit_oid, author, body) do
    case DB.transaction(insert_review_comment(repo.id, commit_oid, author.id, body)) do
      {:ok, %{comment: comment}} ->
        {:ok, struct(comment, repo: repo, author: author)}
      {:error, _operation, reason, _changes} ->
        {:error, reason}
    end
  end

  @doc """
  Returns a commit review changeset for the given `params`.
  """
  @spec changeset(t, map) :: Ecto.Changeset.t
  def changeset(%__MODULE__{} = commit_comment, params \\ %{}) do
    commit_comment
    |> cast(params, [:repo_id, :commit_oid])
    |> cast_assoc(:comments, with: &Comment.changeset/2)
    |> validate_required([:repo_id, :commit_oid])
    |> assoc_constraint(:repo)
    |> unique_constraint(:commit_oid, name: :commit_reviews_repo_commit_id_oid_index)
  end

  #
  # Helpers
  #

  defp insert_review_comment(repo_id, commit_oid, author_id, body) do
    review_opts = [on_conflict: {:replace, [:updated_at]}, conflict_target: [:repo_id, :commit_oid]]
    Multi.new()
    |> Multi.insert(:review, changeset(%__MODULE__{}, %{repo_id: repo_id, commit_oid: commit_oid}), review_opts)
    |> Multi.insert(:comment, Comment.changeset(%Comment{}, %{repo_id: repo_id, author_id: author_id, body: body}))
    |> Multi.run(:line_review_comment, fn db, %{review: review, comment: comment} ->
      case db.insert_all("commit_reviews_comments", [%{review_id: review.id, comment_id: comment.id}]) do
        {1, val} -> {:ok, val}
      end
    end)
  end
end
