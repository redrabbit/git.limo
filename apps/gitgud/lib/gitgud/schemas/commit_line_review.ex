defmodule GitGud.CommitLineReview do
  @moduledoc """
  Git commit review schema and helper functions.

  A `GitGud.CommitLineReview` represents a comment and it's replies for a given commit line.
  """

  use Ecto.Schema

  alias Ecto.Multi

  alias GitRekt.Git

  alias GitGud.DB
  alias GitGud.User
  alias GitGud.Repo
  alias GitGud.Comment

  import Ecto.Changeset

  schema "commit_line_reviews" do
    belongs_to :repo, Repo
    many_to_many :comments, Comment, join_through: "commit_line_reviews_comments", join_keys: [thread_id: :id, comment_id: :id]
    field :commit_oid, :binary
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
    commit_oid: GitRekt.Git.oid,
    blob_oid: GitRekt.Git.oid,
    hunk: non_neg_integer,
    line: non_neg_integer,
    inserted_at: NaiveDateTime.t,
    updated_at: NaiveDateTime.t
  }

  @doc """
  Adds a new comment.

  ```elixir
  {:ok, comment} = GitGud.CommitLineReview.add_comment(line_review, author, "This is the **new** comment message.")
  ```

  This function validates the given parameters using `changeset/2` and `GitGud.Comment.changeset/2`.
  """
  @spec add_comment(t, User.t, binary, keyword) :: {:ok, Comment.t} | {:error, Ecto.Changeset.t}
  def add_comment(%__MODULE__{id: review_id, repo_id: repo_id} = commit_line_review, %User{id: author_id} = author, body, opts \\ []) do
    case DB.transaction(insert_review_comment(repo_id, review_id, author_id, body)) do
      {:ok, %{comment: comment}} ->
        if Keyword.get(opts, :with_review, false),
          do: {:ok, struct(comment, author: author), commit_line_review},
        else: {:ok, struct(comment, author: author)}
      {:error, _operation, reason, _changes} ->
        {:error, reason}
    end
  end

  @doc """
  Adds a new comment.

  ```elixir
  {:ok, comment} = GitGud.CommitLineReview.add_comment(
    repo,
    commit_oid,
    blob_oid,
    hunk,
    line,
    author,
    "This is the **new** comment message."
  )
  ```

  This function validates the given parameters using `changeset/2` and `GitGud.Comment.changeset/2`.
  """
  @spec add_comment(Repo.t, Git.oid, Git.oid, non_neg_integer, non_neg_integer, User.t, binary, keyword) :: {:ok, Comment.t} | {:error, Ecto.Changeset.t}
  def add_comment(%Repo{id: repo_id} = repo, commit_oid, blob_oid, hunk, line, %User{id: author_id} = author, body, opts \\ []) do
    case DB.transaction(insert_review_comment(repo_id, commit_oid, blob_oid, hunk, line, author_id, body)) do
      {:ok, %{review: commit_line_review, comment: comment}} ->
        if Keyword.get(opts, :with_review, false),
          do: {:ok, struct(comment, author: author), commit_line_review},
        else: {:ok, struct(comment, author: author)}
      {:error, _operation, reason, _changes} ->
        {:error, reason}
    end
  end

  @doc """
  Similar to `add_comment/4`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec add_comment!(t, User.t, binary, keyword) :: Comment.t
  def add_comment!(commit_line_review, author, body, opts \\ []) do
    case add_comment(commit_line_review, author, body, opts) do
      {:ok, comment} ->
        comment
      {:ok, comment, review} ->
        {comment, review}
      {:error, changeset} ->
        raise Ecto.InvalidChangesetError, action: changeset.action, changeset: changeset
    end
  end

  @doc """
  Similar to `add_comment/8`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec add_comment!(Repo.t, Git.oid, Git.oid, non_neg_integer, non_neg_integer, User.t, binary, keyword) :: Comment.t
  def add_comment!(repo, commit_oid, blob_oid, hunk, line, author, body, opts \\ []) do
    case add_comment(repo, commit_oid, blob_oid, hunk, line, author, body, opts) do
      {:ok, comment} ->
        comment
      {:ok, comment, review} ->
        {comment, review}
      {:error, changeset} ->
        raise Ecto.InvalidChangesetError, action: changeset.action, changeset: changeset
    end
  end

  @doc """
  Returns a changeset for the given `params`.
  """
  @spec changeset(t, map) :: Ecto.Changeset.t
  def changeset(%__MODULE__{} = commit_line_review, params \\ %{}) do
    commit_line_review
    |> cast(params, [:repo_id, :commit_oid, :blob_oid, :hunk, :line])
    |> cast_assoc(:comments, with: &Comment.changeset/2)
    |> validate_required([:repo_id, :commit_oid, :blob_oid, :hunk, :line])
    |> assoc_constraint(:repo)
    |> unique_constraint(:line, name: :commit_line_reviews_repo_commit_id_oid_blob_oid_hunk_line_index)
  end

  #
  # Helpers
  #

  defp insert_review_comment(repo_id, commit_oid, blob_oid, hunk, line, author_id, body) do
    review_opts = [on_conflict: {:replace, [:updated_at]}, conflict_target: [:repo_id, :commit_oid, :blob_oid, :hunk, :line]]
    Multi.new()
    |> Multi.insert(:review, changeset(%__MODULE__{}, %{repo_id: repo_id, commit_oid: commit_oid, blob_oid: blob_oid, hunk: hunk, line: line}), review_opts)
    |> Multi.merge(fn %{review: review} -> insert_review_comment(repo_id, review.id, author_id, body) end)
  end

  defp insert_review_comment(repo_id, review_id, author_id, body) do
    Multi.new()
    |> Multi.insert(:comment, Comment.changeset(%Comment{}, %{repo_id: repo_id, thread_table: "commit_line_reviews_comments", author_id: author_id, body: body}))
    |> Multi.run(:review_comment, fn db, %{comment: comment} -> insert_review_comment(db, review_id, comment.id) end)
  end

  defp insert_review_comment(db, review_id, comment_id) when is_atom(db) do
    case db.insert_all("commit_line_reviews_comments", [%{thread_id: review_id, comment_id: comment_id}]) do
      {1, val} -> {:ok, val}
    end
  end
end
