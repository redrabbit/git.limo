defmodule GitGud.CommitQuery do
  @moduledoc """
  Conveniences for commit related queries.
  """

  @behaviour GitGud.DBQueryable

  alias GitGud.DB
  alias GitGud.DBQueryable

  alias GitGud.Commit
  alias GitGud.Repo

  import Ecto.Query

  @doc """
  Returns a commit for the given `oid`.
  """
  @spec by_oid(Repo.t | pos_integer, GitRekt.Git.oid, keyword) :: Commit.t | nil
  def by_oid(repo, oid, opts \\ []) do
    DB.one(DBQueryable.query({__MODULE__, :commit_query}, [repo, oid], opts))
  end

  @doc """
  Returns the number of ancestors for the given `repo` and `commit`.
  """
  @spec count_ancestors(Repo.t | pos_integer, Commit.t | GitRekt.Git.oid, keyword) :: non_neg_integer
  def count_ancestors(repo, commit, opts \\ []) do
    DB.one(DBQueryable.query({__MODULE__, :ancestors_count_query}, [repo, commit], opts))
  end

  @doc """
  Returns the commit history starting from the given `commit`.
  """
  @spec history(Repo.t | pos_integer, Commit.t | GitRekt.Git.oid, keyword) :: [Commit.t]
  def history(repo, commit, opts \\ []) do
    DB.all(DBQueryable.query({__MODULE__, :history_query}, [repo, commit], opts))
  end

  @doc """
  Returns a query for fetching the commit with the given `oid`.
  """
  @spec commit_query(Repo.t | pos_integer, GitRekt.Git.oid) :: Ecto.Query
  def commit_query(%Repo{id: repo_id}, oid), do: commit_query(repo_id, oid)
  def commit_query(repo_id, oid) when is_integer(repo_id) and is_binary(oid) do
    from(c in Commit, where: c.oid == ^oid)
  end

  @doc """
  Returns a query for fetching the commit history starting from the given `commit`.
  """
  @spec history_query(Repo.t | pos_integer, Commit.t | GitRekt.Git.oid) :: Ecto.Query
  def history_query(%Repo{id: repo_id} = _repo, %Commit{oid: oid} = _commit), do: history_query(repo_id, oid)
  def history_query(%Repo{id: repo_id}, oid), do: history_query(repo_id, oid)
  def history_query(repo_id, %Commit{oid: oid}), do: history_query(repo_id, oid)
  def history_query(repo_id, oid) when is_integer(repo_id) and is_binary(oid) do
    Commit
    |> join(:inner, [c], f in fragment("commits_dag_desc(?, ?)", ^repo_id, ^oid), on: c.oid == f.oid)
    |> order_by([c], [desc: :committed_at])
  end

  @doc """
  Returns a query for counting the number of ancestors for the given `commit`.
  """
  @spec ancestors_count_query(Repo.t | pos_integer, Commit.t | GitRekt.Git.oid) :: Ecto.Query
  def ancestors_count_query(%Repo{id: repo_id} = _repo, %Commit{oid: oid} = _commit), do: ancestors_count_query(repo_id, oid)
  def ancestors_count_query(%Repo{id: repo_id}, oid), do: ancestors_count_query(repo_id, oid)
  def ancestors_count_query(repo_id, %Commit{oid: oid}), do: ancestors_count_query(repo_id, oid)
  def ancestors_count_query(repo_id, oid) when is_integer(repo_id) and is_binary(oid) do
    Commit
    |> join(:inner, [c], f in fragment("commits_dag_desc(?, ?)", ^repo_id, ^oid), on: c.oid == f.oid)
    |> select([c], count(c.oid))
  end

  #
  # Callbacks
  #

  @impl true
  def alter_query(query, _preloads, _viewer), do: query
end
