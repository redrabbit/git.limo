defmodule GitGud.IssueQuery do
  @moduledoc """
  Conveniences for issue related queries.
  """

  @behaviour GitGud.DBQueryable

  alias GitGud.DB
  alias GitGud.DBQueryable

  alias GitGud.Repo
  alias GitGud.Issue
  alias GitGud.Comment

  import Ecto.Query

  @doc """
  Returns a repository issue for the given `id`.
  """
  @spec by_id(pos_integer, keyword) :: Issue.t | nil
  def by_id(id, opts \\ []) do
    DB.one(DBQueryable.query({__MODULE__, :issue_query}, id, opts))
  end

  @doc """
  Returns a repository issue for the given `number`.
  """
  @spec repo_issue(Repo.t | pos_integer, pos_integer, keyword) :: Issue.t | nil
  def repo_issue(repo, number, opts \\ [])
  def repo_issue(%Repo{id: repo_id} = _repo, number, opts) do
    DB.one(DBQueryable.query({__MODULE__, :repo_issue_query}, [repo_id, number], opts))
  end

  def repo_issue(repo_id, number, opts) do
    DB.one(DBQueryable.query({__MODULE__, :repo_issue_query}, [repo_id, number], opts))
  end

  @doc """
  Returns all issues for the given `repo`.
  """
  @spec repo_issues(Repo.t | pos_integer, keyword) :: [Issue.t]
  def repo_issues(repo, opts \\ [])
  def repo_issues(%Repo{id: repo_id} = _repo, opts) do
    {status, opts} = Keyword.pop(opts, :status, :all)
    {numbers, opts} = Keyword.pop(opts, :numbers)
    DB.all(DBQueryable.query({__MODULE__, :repo_issues_query}, [repo_id, numbers || status], opts))
  end

  def repo_issues(repo_id, opts) do
    {status, opts} = Keyword.pop(opts, :status, :all)
    {numbers, opts} = Keyword.pop(opts, :numbers)
    DB.all(DBQueryable.query({__MODULE__, :repo_issues_query}, [repo_id, numbers || status], opts))
  end

  @doc """
  Returns all issues and their number of comments for the given `repo`.
  """
  @spec repo_issues_with_comments_count(Repo.t | pos_integer, keyword) :: [{Issue.t, pos_integer}]
  def repo_issues_with_comments_count(%Repo{id: repo_id} = _repo, opts) do
    {status, opts} = Keyword.pop(opts, :status, :all)
    DB.all(DBQueryable.query({__MODULE__, :repo_issues_with_comments_count_query}, [repo_id, status], opts))
  end

  def repo_issues_with_comments_count(repo_id, opts) do
    {status, opts} = Keyword.pop(opts, :status, :all)
    DB.all(DBQueryable.query({__MODULE__, :repo_issues_with_comments_count_query}, [repo_id, status], opts))
  end

  @doc """
  Returns the number of issues for the given `repo`.
  """
  @spec count_repo_issues(Repo.t | pos_integer, keyword) :: non_neg_integer | nil
  def count_repo_issues(repo, opts \\ [])
  def count_repo_issues(%Repo{id: repo_id} = _repo, opts) do
    {status, opts} = Keyword.pop(opts, :status, :all)
    DB.one(DBQueryable.query({__MODULE__, :count_repo_issues_query}, [repo_id, status], opts))
  end

  def count_repo_issues(repo_id, opts) do
    {status, opts} = Keyword.pop(opts, :status, :all)
    DB.one(DBQueryable.query({__MODULE__, :count_repo_issues_query}, [repo_id, status], opts))
  end

  @doc """
  Returns a query for fetching a repository issue by its `id`.
  """
  @spec issue_query(pos_integer) :: Ecto.Query.t
  def issue_query(id) do
    from(i in Issue, as: :issue, where: i.id == ^id)
  end

  @doc """
  Returns a query for fetching a repository issue by its `number`.
  """
  @spec repo_issue_query(pos_integer, pos_integer) :: Ecto.Query.t
  def repo_issue_query(repo_id, number) when is_integer(number) do
    from(i in Issue, as: :issue, where: i.repo_id == ^repo_id and i.number == ^number)
  end

  @doc """
  Returns a query for fetching all repository issues.
  """
  @spec repo_issues_query(pos_integer) :: Ecto.Query.t
  def repo_issues_query(repo_id), do: repo_issues_query(repo_id, :all)

  @doc """
  Returns a query for fetching all repository issues with the given `status`.
  """
  @spec repo_issues_query(pos_integer, [pos_integer] | atom) :: Ecto.Query.t
  def repo_issues_query(repo_id, numbers_or_status)
  def repo_issues_query(repo_id, numbers) when is_list(numbers) do
    from(i in Issue, as: :issue, where: i.repo_id == ^repo_id and i.number in ^numbers)
  end

  def repo_issues_query(repo_id, :all) do
    from(i in Issue, as: :issue, where: i.repo_id == ^repo_id)
  end

  def repo_issues_query(repo_id, status) do
    from(i in Issue, as: :issue, where: i.repo_id == ^repo_id and i.status == ^to_string(status))
  end

  @doc """
  Returns a query for fetching all repository issues and their number of comments.
  """
  @spec repo_issues_with_comments_count_query(pos_integer, atom) :: Ecto.Query.t
  def repo_issues_with_comments_count_query(repo_id, status) do
    repo_issues_query(repo_id, status)
    |> join(:inner, [issue: i], c in assoc(i, :comments), as: :comment)
    |> group_by([issue: i], i.id)
    |> select([issue: i, comment: c], {i, count(c)})
  end

  @doc """
  Returns a query for counting the number of issues of a repository.
  """
  @spec count_repo_issues_query(pos_integer, atom) :: Ecto.Query.t
  def count_repo_issues_query(repo_id, status \\ :all) do
    repo_id
    |> repo_issues_query(status)
    |> select([issue: e], count())
  end

  @doc """
  Returns a query for fetching comments of an issue.
  """
  @spec comments_query(Issue.t | pos_integer) :: Ecto.Query.t
  def comments_query(%Issue{id: issue_id} = _issue), do: comments_query(issue_id)
  def comments_query(issue_id) when is_integer(issue_id) do
    from c in Comment, as: :comment, join: t in "issues_comments", on: t.comment_id == c.id, where: t.thread_id == ^issue_id
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

  defp join_preload(query, preload, _viewer) do
    preload(query, ^preload)
  end
end
