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
  alias GitGud.Comment
  alias GitGud.CommitLineReview

  import Ecto.Query

  @doc """
  Returns a commit line review for the given `id`.
  """
  @spec commit_line_review(pos_integer, keyword) :: CommitLineReview.t | nil
  def commit_line_review(id, opts \\ []) do
    DB.one(DBQueryable.query({__MODULE__, :commit_line_review_query}, [id], opts))
  end

  @doc """
  Returns a commit line review for the given `repo`, `commit`, `blob_oid`, `hunk` and `line`.
  """
  @spec commit_line_review(Repo.t | pos_integer, GitCommit.t | Git.oid, Git.oid, non_neg_integer, non_neg_integer, keyword) :: CommitLineReview.t | nil
  def commit_line_review(repo, commit, blob_oid, hunk, line, opts \\ [])
  def commit_line_review(%Repo{id: repo_id} = _repo, commit_oid, blob_oid, hunk, line, opts), do: commit_line_review(repo_id, commit_oid, blob_oid, hunk, line, opts)
  def commit_line_review(repo_id, %GitCommit{oid: commit_oid} = _commit, blob_oid, hunk, line, opts), do: commit_line_review(repo_id, commit_oid, blob_oid, hunk, line, opts)
  def commit_line_review(repo_id, commit_oid, blob_oid, hunk, line, opts) do
    DB.one(DBQueryable.query({__MODULE__, :commit_line_review_query}, [repo_id, commit_oid, blob_oid, hunk, line], opts))
  end

  @doc """
  Returns commit line reviews for the given `repo` and `commit`.
  """
  @spec commit_line_reviews(Repo.t | pos_integer, GitCommit.t | Git.oid, keyword) :: [CommitLineReview.t]
  def commit_line_reviews(repo, commit, opts \\ [])
  def commit_line_reviews(%Repo{id: repo_id} = _repo, commit_oid, opts), do: commit_line_reviews(repo_id, commit_oid, opts)
  def commit_line_reviews(repo_id, %GitCommit{oid: commit_oid} = _commit, opts), do: commit_line_reviews(repo_id, commit_oid, opts)
  def commit_line_reviews(repo_id, commit_oid, opts), do: DB.all(DBQueryable.query({__MODULE__, :commit_line_reviews_query}, [repo_id, commit_oid], opts))

  @doc """
  Returns comments for the given `repo` and `commit`.
  """
  @spec commit_line_reviews_comments(Repo.t | pos_integer, GitCommit.t | Git.oid, keyword) :: [CommitLineReview.t]
  def commit_line_reviews_comments(repo, commit, opts \\ [])
  def commit_line_reviews_comments(%Repo{id: repo_id} = _repo, commit_oid, opts), do: commit_line_reviews_comments(repo_id, commit_oid, opts)
  def commit_line_reviews_comments(repo_id, %GitCommit{oid: commit_oid} = _commit, opts), do: commit_line_reviews_comments(repo_id, commit_oid, opts)
  def commit_line_reviews_comments(repo_id, commit_oid, opts) do
    {preloads, opts} = Keyword.pop(opts, :preload, [])
    reviews_comments = DB.all(DBQueryable.query({__MODULE__, :commit_line_reviews_comments_query}, [repo_id, commit_oid], opts))
    {review_ids, comments} = Enum.unzip(reviews_comments)
    reviews_comments = Enum.zip(review_ids, DB.preload(comments, preloads))
    Enum.reduce(reviews_comments, %{}, fn {review_id, comment}, acc ->
      Map.update(acc, review_id, [comment], &[comment|&1])
    end)
  end

  @doc """
  Returns the number of comments for the given `repo` and `commit`.
  """
  @spec count_comments(Repot.t | pos_integer, GitCommit.t | Git.oid) :: non_neg_integer
  @spec count_comments(Repot.t | pos_integer, [GitCommit.t] | [Git.oid]) :: {Git.oid, non_neg_integer()}
  def count_comments(repo, commit)
  def count_comments(%Repo{id: repo_id} = _repo, commits) when is_list(commits), do: count_comments(repo_id, commits)
  def count_comments(repo_id, commits) when is_list(commits) do
    cond do
      Enum.all?(commits, &is_struct(&1, GitCommit)) ->
        DB.all(query(:count_commit_line_review_comments_query, [repo_id, Enum.map(commits, &(&1.oid))]))
      Enum.all?(commits, &is_binary/1) ->
        DB.all(query(:count_commit_line_review_comments_query, [repo_id, commits]))
    end
  end

  def count_comments(%Repo{id: repo_id} = _repo, commit_oid), do: count_comments(repo_id, commit_oid)
  def count_comments(repo_id, %GitCommit{oid: commit_oid}), do: count_comments(repo_id, commit_oid)
  def count_comments(repo_id, commit_oid) do
    DB.one(query(:count_commit_line_review_comments_query, [repo_id, commit_oid]))
  end

  @doc """
  Returns the number of of comments grouped by blob oid for the given `repo` and `commit`.
  """
  @spec count_comments_by_blob(Repo.t | pos_integer, GitCommit.t | Git.oid) :: %{binary => pos_integer}
  def count_comments_by_blob(%Repo{id: repo_id} = _repo, commit_oid), do: count_comments_by_blob(repo_id, commit_oid)
  def count_comments_by_blob(repo_id, %GitCommit{oid: commit_oid}), do: count_comments_by_blob(repo_id, commit_oid)
  def count_comments_by_blob(repo_id, commit_oid) do
    query(:count_commit_line_review_comments_by_blob_query, [repo_id, commit_oid])
    |> DB.all()
    |> Map.new()
  end

  #
  # Callbacks
  #

  @impl true
  def query(:commit_line_review_query, [id]) when is_integer(id) do
    from(r in CommitLineReview, as: :review, where: r.id == ^id)
  end

  def query(:commit_line_review_query, [repo_id, id]) when is_integer(repo_id) and is_integer(id) do
    from(r in CommitLineReview, as: :review, where: r.repo_id == ^repo_id and r.id == ^id)
  end

  def query(:commit_line_review_query, [repo_id, commit_oid, blob_oid, hunk, line]) when is_integer(repo_id) do
    from(r in CommitLineReview, as: :review, where: r.repo_id == ^repo_id and r.commit_oid == ^commit_oid and r.blob_oid == ^blob_oid and r.hunk == ^hunk and r.line == ^line)
  end

  def query(:commit_line_reviews_query, [repo_id, commit_oid]) when is_integer(repo_id) do
    from(r in CommitLineReview, as: :review, where: r.repo_id == ^repo_id and r.commit_oid == ^commit_oid)
  end

  def query(:commit_line_reviews_comments_query, [repo_id, commit_oid]) when is_integer(repo_id) do
    from r in CommitLineReview, as: :review, where: r.repo_id == ^repo_id and r.commit_oid == ^commit_oid, join: c in assoc(r, :comments), select: {r.id, c}
  end

  def query(:count_commit_line_review_comments_query, [repo_id, commit_oids]) when is_integer(repo_id) and is_list(commit_oids) do
    from r in CommitLineReview, where: r.repo_id == ^repo_id and r.commit_oid in ^commit_oids, join: c in assoc(r, :comments), group_by: r.commit_oid, select: {r.commit_oid, count(c.id)}
  end

  def query(:count_commit_line_review_comments_query, [repo_id, commit_oid]) when is_integer(repo_id) do
    from r in CommitLineReview, where: r.repo_id == ^repo_id and r.commit_oid == ^commit_oid, join: c in assoc(r, :comments), select: count(c.id)
  end

  def query(:count_commit_line_review_comments_by_blob_query, [repo_id, commit_oid]) when is_integer(repo_id) do
    from r in CommitLineReview, where: r.repo_id == ^repo_id and r.commit_oid == ^commit_oid, join: c in assoc(r, :comments), group_by: r.blob_oid, select: {r.blob_oid, count(c.id)}
  end

  def query(:comments_query, [%{id: review_id, __struct__: struct} = _review]), do: query(:comments_query, [{struct, review_id}])
  def query(:comments_query, [{CommitLineReview, review_id}]) when is_integer(review_id) do
    from c in Comment, join: t in "commit_line_reviews_comments", on: t.comment_id == c.id, where: t.thread_id == ^review_id
  end

  def query(:comments_query, [{CommitLineReview, review_ids}]) when is_list(review_ids) do
    from c in Comment, as: :comment, join: t in "commit_line_reviews_comments", on: t.comment_id == c.id, where: t.thread_id in ^review_ids
  end

  @impl true
  def alter_query(query, _viewer), do: query

  @impl true
  def preload_query(query, [], _viewer), do: query

  def preload_query(query, [preload|tail], viewer) do
    query
    |> join_preload(preload, viewer)
    |> preload_query(tail, viewer)
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
