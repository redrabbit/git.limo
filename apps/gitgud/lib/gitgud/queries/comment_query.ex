defmodule GitGud.CommentQuery do
  @moduledoc """
  Conveniences for comment related queries.
  """

  @behaviour GitGud.DBQueryable

  alias GitGud.DB
  alias GitGud.DBQueryable

  alias GitGud.Comment

  import Ecto.Query

  @doc """
  Returns a comment for the given `id`.
  """
  @spec by_id(pos_integer, keyword) :: Comment.t | nil
  def by_id(id, opts \\ []) do
    DB.one(DBQueryable.query({__MODULE__, :comment_query}, [id], opts))
  end

  @doc """
  Returns the thread associated to the given `comment`.
  """
  @spec thread(Comment.t) :: struct | nil
  def thread(%Comment{id: id, thread_table: table} = _comment, opts \\ []) do
    DB.one(DBQueryable.query({__MODULE__, :thread_query}, [id, table], opts))
  end

  #
  # Callbacks
  #

  @impl true
  def query(:comment_query, [id]) do
    from(r in Comment, as: :comment, where: r.id == ^id)
  end

  def query(:thread_query, [id, table]) do
    from r in thread_struct(table), join: t in ^table, on: [comment_id: ^id], where: t.thread_id == r.id
  end

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

  defp join_preload(query, :author, _viewer) do
    query
    |> join(:left, [comment: c], a in assoc(c, :author), as: :author)
    |> preload([author: a], [author: a])
  end

  defp join_preload(query, preload, _viewer) do
    preload(query, ^preload)
  end

  defp thread_struct("issues_comments"), do: GitGud.Issue
  defp thread_struct("commit_line_reviews_comments"), do: GitGud.CommitLineReview
  defp thread_struct("commit_reviews_comments"), do: GitGud.CommitReview
end
