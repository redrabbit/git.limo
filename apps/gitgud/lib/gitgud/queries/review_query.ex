defmodule GitGud.ReviewQuery do
  @moduledoc """
  Conveniences for review related queries.
  """

  @behaviour GitGud.DBQueryable

  alias GitGud.DB
  alias GitGud.DBQueryable

  alias GitGud.Repo
  alias GitGud.CommitLineReview

  import Ecto.Query

  def commit_line_review_by_id(id, opts \\ []) do
    DB.one(DBQueryable.query({__MODULE__, :commit_line_review_query}, [id], opts))
  end

  def commit_line_review(%Repo{id: repo_id} = _repo, id, opts \\ []) do
    DB.one(DBQueryable.query({__MODULE__, :commit_line_review_query}, [repo_id, id], opts))
  end

  def commit_line_review(%Repo{id: repo_id} = _repo, commit, blob_oid, hunk, line, opts \\ []) do
    DB.one(DBQueryable.query({__MODULE__, :commit_line_review_query}, [repo_id, commit.oid, blob_oid, hunk, line], opts))
  end

  def commit_line_reviews(%Repo{id: repo_id} = _repo, commit, opts \\ []) do
    DB.all(DBQueryable.query({__MODULE__, :commit_line_reviews_query}, [repo_id, commit.oid], opts))
  end

  def commit_line_review_query(id) do
    from(r in CommitLineReview, as: :review, where: r.id == ^id)
  end

  def commit_line_review_query(repo_id, id) do
    from(r in CommitLineReview, as: :review, where: r.repo_id == ^repo_id and r.id == ^id)
  end

  def commit_line_review_query(repo_id, commit_oid, blob_oid, hunk, line) do
    from(r in CommitLineReview, as: :review, where: r.repo_id == ^repo_id and r.commit_oid == ^commit_oid and r.blob_oid == ^blob_oid and r.hunk == ^hunk and r.line == ^line)
  end

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
    |> join(:left, [review: r], r2 in assoc(r, :repo), as: :repo)
    |> preload([repo: r2], [repo: r2])
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
