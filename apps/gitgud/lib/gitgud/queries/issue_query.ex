defmodule GitGud.IssueQuery do
  @moduledoc """
  Conveniences for issue related queries.
  """

  @behaviour GitGud.DBQueryable

  alias GitGud.DB
  alias GitGud.DBQueryable

  alias GitGud.Repo
  alias GitGud.Issue
  alias GitGud.IssueLabel
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
  def repo_issue(%Repo{id: repo_id}, number, opts) do
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
  def repo_issues(%Repo{id: repo_id}, opts), do: repo_issues(repo_id, opts)
  def repo_issues(repo_id, opts) do
    {numbers, opts} = Keyword.pop(opts, :numbers)
    {status, opts} = Keyword.pop(opts, :status, :all)
    {labels, opts} = Keyword.pop(opts, :labels, [])
    DB.all(DBQueryable.query({__MODULE__, :repo_issues_query}, [repo_id, numbers || status, labels], opts))
  end

  @doc """
  Returns all issues and their number of comments for the given `repo`.
  """
  @spec repo_issues_with_comments_count(Repo.t | pos_integer, keyword) :: [{Issue.t, pos_integer}]
  def repo_issues_with_comments_count(repo, opts \\ [])
  def repo_issues_with_comments_count(%Repo{id: repo_id}, opts), do: repo_issues_with_comments_count(repo_id, opts)
  def repo_issues_with_comments_count(repo_id, opts) do
    {status, opts} = Keyword.pop(opts, :status, :all)
    {labels, opts} = Keyword.pop(opts, :labels, [])
    DB.all(DBQueryable.query({__MODULE__, :repo_issues_with_comments_count_query}, [repo_id, status, labels], opts))
  end

  @doc """
  Returns all issue labels for the given `repo`.
  """
  @spec repo_labels(Repo.t | pos_integer, keyword) :: [IssueLabel.t]
  def repo_labels(repo, opts \\ [])
  def repo_labels(%Repo{id: repo_id}, opts), do: repo_labels(repo_id, opts)
  def repo_labels(repo_id, opts) do
    DB.all(DBQueryable.query({__MODULE__, :repo_labels_query}, [repo_id], opts))
  end

  @doc """
  Returns the number of issues for the given `repo`.
  """
  @spec count_repo_issues(Repo.t | pos_integer, keyword) :: non_neg_integer | nil
  def count_repo_issues(repo, opts \\ [])
  def count_repo_issues(%Repo{id: repo_id}, opts), do: count_repo_issues(repo_id, opts)
  def count_repo_issues(repo_id, opts) do
    {status, opts} = Keyword.pop(opts, :status, :all)
    {labels, opts} = Keyword.pop(opts, :labels, [])
    DB.one(DBQueryable.query({__MODULE__, :count_repo_issues_query}, [repo_id, status, labels], opts))
  end

  #
  # Callbacks
  #

  @impl true
  def query(:issue_query, [id]) do
    from(i in Issue, as: :issue, where: i.id == ^id)
  end

  def query(:repo_issue_query, [repo_id, number]) when is_integer(number) do
    from(i in Issue, as: :issue, where: i.repo_id == ^repo_id and i.number == ^number)
  end

  def query(:repo_issues_query, [repo_id]), do: query(:repo_issues_query, [repo_id, :all])

  def query(:repo_issues_query, [repo_id, numbers]) when is_list(numbers) do
    from(i in Issue, as: :issue, where: i.repo_id == ^repo_id and i.number in ^numbers)
  end

  def query(:repo_issues_query, [repo_id, :all]) do
    from(i in Issue, as: :issue, where: i.repo_id == ^repo_id)
  end

  def query(:repo_issues_query, [repo_id, status]) do
    from(i in Issue, as: :issue, where: i.repo_id == ^repo_id and i.status == ^to_string(status))
  end

  def query(:repo_issues_query, [repo_id, status, labels]) do
    query(:repo_issues_query, [repo_id, status])
    |> join(:inner, [issue: i], l in assoc(i, :labels), as: :labels)
    |> group_by([issue: i], i.id)
    |> having([issue: i, labels: l], fragment("array_agg(?) @> (?)::varchar[]", l.name, ^labels))
  end

  def query(:repo_issues_with_comments_count_query, args) do
    query(:repo_issues_query, args)
    |> join(:inner, [issue: i], c in assoc(i, :comments), as: :comment)
    |> group_by([issue: i], i.id)
    |> select([issue: i, comment: c], {i, count(c.id, :distinct)})
  end

  def query(:repo_labels_query, [repo_id]) do
    from(l in IssueLabel, as: :label, where: l.repo_id == ^repo_id)
  end

  def query(:count_repo_issues_query, [repo_id, status]) do
    select(query(:repo_issues_query, [repo_id, status]), [issue: e], count())
  end

  def query(:count_repo_issues_query, [repo_id, status, []]), do: query(:count_repo_issues_query, [repo_id, status])
  def query(:count_repo_issues_query, [repo_id, status, labels]) do
    select(query(:repo_issues_query, [repo_id, status, labels]), [issue: e], count())
  end

  def query(:comments_query, [%Issue{id: issue_id} = _issue]), do: query(:comments_query, [issue_id])
  def query(:comments_query, [issue_id]) when is_integer(issue_id) do
    from c in Comment, as: :comment, join: t in "issues_comments", on: t.comment_id == c.id, where: t.thread_id == ^issue_id
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

  defp join_preload(query, preload, _viewer) do
    preload(query, ^preload)
  end
end
