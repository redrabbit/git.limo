defmodule GitGud.IssueQuery do
  @moduledoc """
  Conveniences for issue related queries.
  """

  @behaviour GitGud.DBQueryable

  alias GitGud.DB
  alias GitGud.DBQueryable

  alias GitGud.Repo
  alias GitGud.Issue

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
  @spec repo_issues(Repo.t | pos_integer, keyword) :: Issue.t | nil
  def repo_issues(repo, opts \\ [])
  def repo_issues(%Repo{id: repo_id} = _repo, opts) do
    {status, opts} = Keyword.pop(opts, :status, :all)
    DB.all(DBQueryable.query({__MODULE__, :repo_issues_query}, [repo_id, status], opts))
  end

  def repo_issues(repo_id, opts) do
    {status, opts} = Keyword.pop(opts, :status, :all)
    DB.all(DBQueryable.query({__MODULE__, :repo_issues_query}, [repo_id, status], opts))
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

  def repo_issues_query(repo_id, :all) do
    from(i in Issue, as: :issue, where: i.repo_id == ^repo_id)
  end

  def repo_issues_query(repo_id, status) do
    from(i in Issue, as: :issue, where: i.repo_id == ^repo_id and i.status == ^status)
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
