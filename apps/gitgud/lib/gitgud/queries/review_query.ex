defmodule GitGud.ReviewQuery do
  @moduledoc """
  Conveniences for review related queries.
  """

  @behaviour GitGud.DBQueryable

  alias GitGud.DB
  alias GitGud.DBQueryable

  alias GitRekt.Git
  alias GitRekt.GitAgent

  alias GitGud.Repo
  alias GitGud.CommitLineReview

  import Ecto.Query

  @doc """
  Returns a commit line review for the given `id`.
  """
  @spec commit_line_review_by_id(pos_integer, keyword) :: CommitLineReview.t | nil
  def commit_line_review_by_id(id, opts \\ []) do
    DB.one(DBQueryable.query({__MODULE__, :commit_line_review_query}, [id], opts))
  end

  @doc """
  Returns a commit line review for the given `repo` and `id`.
  """
  @spec commit_line_review(Repo.t, pos_integer, keyword) :: CommitLineReview.t | nil
  def commit_line_review(%Repo{id: repo_id} = _repo, id, opts \\ []) do
    DB.one(DBQueryable.query({__MODULE__, :commit_line_review_query}, [repo_id, id], opts))
  end

  @doc """
  Returns a commit line review for the given `repo`, `commit`, `blob_oid`, `hunk` and `line`.
  """
  @spec commit_line_review(Repo.t, GitAgent.git_commit, Git.oid, non_neg_integer, non_neg_integer, keyword) :: CommitLineReview.t | nil
  def commit_line_review(%Repo{id: repo_id} = _repo, commit, blob_oid, hunk, line, opts \\ []) do
    DB.one(DBQueryable.query({__MODULE__, :commit_line_review_query}, [repo_id, commit.oid, blob_oid, hunk, line], opts))
  end

  @doc """
  Returns all commit line reviews for the given `repo` and `commit`.
  """
  @spec commit_line_reviews(Repo.t, GitAgent.git_commit, keyword) :: [CommitLineReview.t]
  def commit_line_reviews(%Repo{id: repo_id} = _repo, commit, opts \\ []) do
    DB.all(DBQueryable.query({__MODULE__, :commit_line_reviews_query}, [repo_id, commit.oid], opts))
  end

  @doc """
  Returns a query for fetching a single commit line review.
  """
  @spec commit_line_review_query(pos_integer) :: Ecto.Query.t
  def commit_line_review_query(id) do
    from(r in CommitLineReview, as: :review, where: r.id == ^id)
  end

  @doc """
  Returns a query for fetching a single commit line review.
  """
  @spec commit_line_review_query(pos_integer) :: Ecto.Query.t
  def commit_line_review_query(repo_id, id) do
    from(r in CommitLineReview, as: :review, where: r.repo_id == ^repo_id and r.id == ^id)
  end

  @doc """
  Returns a query for fetching a single commit line review.
  """
  @spec commit_line_review_query(pos_integer, Git.oid, Git.oid, non_neg_integer, non_neg_integer) :: Ecto.Query.t
  def commit_line_review_query(repo_id, commit_oid, blob_oid, hunk, line) do
    from(r in CommitLineReview, as: :review, where: r.repo_id == ^repo_id and r.commit_oid == ^commit_oid and r.blob_oid == ^blob_oid and r.hunk == ^hunk and r.line == ^line)
  end

  @doc """
  Returns a query for fetching all commit line reviews.
  """
  @spec commit_line_review_query(pos_integer, Git.oid, Git.oid, non_neg_integer, non_neg_integer) :: Ecto.Query.t
  def commit_line_reviews_query(repo_id, commit_oid) do
    from(r in CommitLineReview, as: :review, where: r.repo_id == ^repo_id and r.commit_oid == ^commit_oid)
  end

  #
  # Callbacks
  #

  @impl true
  def alter_query(query, [], _viewer), do: query

  @impl true
  def alter_query(query, [preload|tail], viewer) do
    query
    |> join_preload(preload, viewer)
    |> alter_query(tail, viewer)
  end

  #
  # Helpers
  #

  defp join_preload(query, :repo, _viewer) do
    query
    |> join(:left, [review: r], rp in assoc(r, :repo), as: :repo)
    |> preload([repo: rp], [repo: rp])
  end

  defp join_preload(query, :comments, _viewer) do
    query
    |> join(:left, [review: r], c in assoc(r, :comments), as: :comments)
    |> preload([comments: c], [comments: c])
  end

  defp join_preload(query, {parent, _children} = preload, viewer) do
    query
    |> join_preload(parent, viewer)
    |> preload(^preload)
  end

  defp join_preload(query, preload, _viewer) do
    preload(query, ^preload)
  end
end
