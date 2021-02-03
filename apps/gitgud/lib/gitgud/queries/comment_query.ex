defmodule GitGud.CommentQuery do
  @moduledoc """
  Conveniences for comment related queries.
  """

  @behaviour GitGud.DBQueryable

  alias GitGud.DB
  alias GitGud.DBQueryable

  alias GitGud.User
  alias GitGud.Repo
  alias GitGud.RepoQuery
  alias GitGud.Comment
  alias GitGud.CommentRevision

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
  @spec thread(Comment.t, keyword) :: struct | nil
  def thread(%Comment{id: id, thread_table: table} = _comment, opts \\ []) do
    DB.one(DBQueryable.query({__MODULE__, :thread_query}, [id, table], opts))
  end

  @doc """
  Returns a comment revision for the given `id`.
  """
  @spec revision(pos_integer, keyword) :: CommentRevision.t | nil
  def revision(id, opts \\ []) do
    DB.one(DBQueryable.query({__MODULE__, :revision_query}, [id], opts))
  end

  @doc """
  Returns all the comment revision for the given `comment`.
  """
  @spec revisions(Comment.t | pos_integer, keyword) :: [CommentRevision.t]
  def revisions(comment, opts \\ [])
  def revisions(%Comment{id: id}, opts), do: revisions(id, opts)
  def revisions(id, opts) do
    DB.all(DBQueryable.query({__MODULE__, :revisions_query}, [id], opts))
  end

  @doc """
  Returns a list of permissions for the given `comment` and `user`.
  """
  @spec permissions(Comment.t, User.t | nil, [atom] | nil):: [atom]
  def permissions(comment, user, repo_perms \\ nil)
  def permissions(%Comment{author_id: user_id}, %User{id: user_id}, _repo_perms), do: [:edit, :delete]
  def permissions(%Comment{} = comment, user, repo_perms) do
    repo_perms = repo_perms || repo_perms(comment, user)
    if :admin in repo_perms,
      do: [:edit, :delete],
    else: []
  end

  #
  # Callbacks
  #

  @impl true
  def query(:comment_query, [id]) when is_integer(id) do
    from(r in Comment, as: :comment, where: r.id == ^id)
  end

  def query(:thread_query, [id, table]) when is_integer(id) do
    from r in thread_struct(table), join: t in ^table, on: [comment_id: ^id], where: t.thread_id == r.id
  end

  def query(:revision_query, [id]) when is_integer(id) do
    from(r in CommentRevision, as: :revision, where: r.id == ^id)
  end

  def query(:revisions_query, [id]) when is_integer(id) do
    from(r in CommentRevision, as: :revision, where: r.comment_id == ^id)
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

  defp repo_perms(%Comment{repo: %Repo{} = repo}, user), do: RepoQuery.permissions(repo, user)
  defp repo_perms(%Comment{repo_id: repo_id}, user), do: RepoQuery.permissions(repo_id, user)
end
