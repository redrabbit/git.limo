defmodule GitGud.ReviewQuery do
  @moduledoc """
  Conveniences for review related queries.
  """

  @behaviour GitGud.DBQueryable

  alias GitGud.DB
  alias GitGud.DBQueryable

  alias GitRekt.Git
  alias GitRekt.GitCommit

  alias GitGud.Repo
  alias GitGud.CommitLineReview
  alias GitGud.CommitReview

  import Ecto.Query

  @doc """
  Returns a commit line review for the given `id`.
  """
  @spec commit_line_review_by_id(pos_integer, keyword) :: CommitLineReview.t | nil
  def commit_line_review_by_id(id, opts \\ []) do
    DB.one(DBQueryable.query({__MODULE__, :commit_line_review_query}, [id], opts))
  end

  @doc """
  Returns a commit line review for the given `repo`, `commit`, `blob_oid`, `hunk` and `line`.
  """
  @spec commit_line_review(Repo.t | pos_integer, GitCommit.t | Git.oid, Git.oid, non_neg_integer, non_neg_integer, keyword) :: CommitLineReview.t | nil
  def commit_line_review(repo, commit, blob_oid, hunk, line, opts \\ [])
  def commit_line_review(%Repo{id: repo_id} = _repo, %GitCommit{oid: commit_oid} = _commit, blob_oid, hunk, line, opts) do
    DB.one(DBQueryable.query({__MODULE__, :commit_line_review_query}, [repo_id, commit_oid, blob_oid, hunk, line], opts))
  end

  def commit_line_review(%Repo{id: repo_id} = _repo, commit_oid, blob_oid, hunk, line, opts) do
    DB.one(DBQueryable.query({__MODULE__, :commit_line_review_query}, [repo_id, commit_oid, blob_oid, hunk, line], opts))
  end

  def commit_line_review(repo_id, commit_oid, blob_oid, hunk, line, opts) do
    DB.one(DBQueryable.query({__MODULE__, :commit_line_review_query}, [repo_id, commit_oid, blob_oid, hunk, line], opts))
  end

  @doc """
  Returns all commit line reviews for the given `repo` and `commit`.
  """
  @spec commit_line_reviews(Repo.t | pos_integer, GitCommit.t | Git.oid, keyword) :: [CommitLineReview.t]
  def commit_line_reviews(repo, commit, opts \\ [])
  def commit_line_reviews(%Repo{id: repo_id} = _repo, %GitCommit{oid: commit_oid} = _commit, opts) do
    DB.all(DBQueryable.query({__MODULE__, :commit_line_reviews_query}, [repo_id, commit_oid], opts))
  end

  def commit_line_reviews(%Repo{id: repo_id} = _repo, commit_oid, opts) do
    DB.all(DBQueryable.query({__MODULE__, :commit_line_reviews_query}, [repo_id, commit_oid], opts))
  end

  def commit_line_reviews(repo_id, commit_oid, opts) do
    DB.all(DBQueryable.query({__MODULE__, :commit_line_reviews_query}, [repo_id, commit_oid], opts))
  end

  @doc """
  Returns a commit review for the given `id`.
  """
  @spec commit_review_by_id(pos_integer, keyword) :: CommitReview.t | nil
  def commit_review_by_id(id, opts \\ []) do
    DB.one(DBQueryable.query({__MODULE__, :commit_review_query}, [id], opts))
  end

  @doc """
  Returns a commit review for the given `repo` and `commit`.
  """
  @spec commit_review(Repo.t | pos_integer, GitCommit.t | Git.oid, keyword) :: CommitReview.t | nil
  def commit_review(repo, commit, opts \\ [])
  def commit_review(%Repo{id: repo_id} = _repo, %GitCommit{oid: oid} = _commit, opts) do
    DB.one(DBQueryable.query({__MODULE__, :commit_review_query}, [repo_id, oid], opts))
  end

  def commit_review(%Repo{id: repo_id} = _repo, oid, opts) do
    DB.one(DBQueryable.query({__MODULE__, :commit_review_query}, [repo_id, oid], opts))
  end

  def commit_review(repo_id, oid, opts) do
    DB.one(DBQueryable.query({__MODULE__, :commit_review_query}, [repo_id, oid], opts))
  end

  @doc """
  Returns the number of comments for the given `repo` and `commit`.
  """
  @spec commit_comment_count(Repot.t, GitCommit.t) :: non_neg_integer
  def commit_comment_count(%Repo{id: repo_id} = _repo, %GitCommit{oid: oid} = _commit) do
    DB.one(DBQueryable.query({__MODULE__, :commit_comment_count_query}, [repo_id, oid]))
  end

  def commit_comment_count(%Repo{id: repo_id} = _repo, commits) when is_list(commits) do
    DB.all(DBQueryable.query({__MODULE__, :commit_comment_count_query}, [repo_id, Enum.map(commits, &(&1.oid))]))
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
  @spec commit_line_review_query(pos_integer, pos_integer) :: Ecto.Query.t
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
  @spec commit_line_reviews_query(pos_integer, Git.oid) :: Ecto.Query.t
  def commit_line_reviews_query(repo_id, commit_oid) do
    from(r in CommitLineReview, as: :review, where: r.repo_id == ^repo_id and r.commit_oid == ^commit_oid)
  end

  @doc """
  Returns a query for fetching a single commit review.
  """
  @spec commit_review_query(pos_integer) :: Ecto.Query.t
  def commit_review_query(id) do
    from(r in CommitReview, as: :review, where: r.id == ^id)
  end

  @doc """
  Returns a query for fetching a single commit review.
  """
  @spec commit_review_query(pos_integer, pos_integer) :: Ecto.Query.t
  def commit_review_query(repo_id, id) when is_integer(id) do
    from(r in CommitReview, as: :review, where: r.repo_id == ^repo_id and r.id == ^id)
  end

  @doc """
  Returns a query for fetching a single commit review.
  """
  @spec commit_review_query(pos_integer, Git.oid) :: Ecto.Query.t
  def commit_review_query(repo_id, commit_oid) do
    from(r in CommitReview, as: :review, where: r.repo_id == ^repo_id and r.commit_oid == ^commit_oid)
  end

  @doc """
  Returns a query for counting the number of reviews for a single commit or a list of commits.
  """
  @spec commit_comment_count_query(pos_integer, Git.oid) :: Ecto.Query.t
  def commit_comment_count_query(repo_id, commit_oids) when is_list(commit_oids) do
    query1 = from r in CommitReview, where: r.repo_id == ^repo_id and r.commit_oid in ^commit_oids, join: c in assoc(r, :comments), group_by: r.commit_oid, select: %{commit_oid: r.commit_oid, count: count(c.id)}
    query2 = from r in CommitLineReview, where: r.repo_id == ^repo_id and r.commit_oid in ^commit_oids, join: c in assoc(r, :comments), group_by: r.commit_oid, select: %{commit_oid: r.commit_oid, count: count(c.id)}
    from c in subquery(union_all(query1, ^query2)), group_by: c.commit_oid, select: {c.commit_oid, sum(c.count)}
  end

  def commit_comment_count_query(repo_id, commit_oid) do
    query1 = from r in CommitReview, where: r.repo_id == ^repo_id and r.commit_oid == ^commit_oid, join: c in assoc(r, :comments), select: c
    query2 = from r in CommitLineReview, where: r.repo_id == ^repo_id and r.commit_oid == ^commit_oid, join: c in assoc(r, :comments), select: c
    from c in subquery(union_all(query1, ^query2)), select: count(c.id)
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
