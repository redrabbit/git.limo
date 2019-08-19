defmodule GitGud.CommitQuery do
  @moduledoc """
  Conveniences for commit related queries.
  """

  @behaviour GitGud.DBQueryable

  alias Git

  alias GitGud.DB
  alias GitGud.DBQueryable

  alias GitGud.Repo
  alias GitGud.Commit
  alias GitGud.GPGKey

  import Ecto.Query

  @doc """
  Returns a commit for the given `oid`.
  """
  @spec by_oid(Repo.t | pos_integer, Git.oid, keyword) :: Commit.t | nil
  def by_oid(repo, oid, opts \\ []) do
    DB.one(DBQueryable.query({__MODULE__, :commit_query}, [repo, oid], opts))
  end

  @doc """
  Returns the number of ancestors for the given `repo` and `commit`.
  """
  @spec count_ancestors(Repo.t | pos_integer, Commit.t | Git.oid, keyword) :: non_neg_integer
  def count_ancestors(repo, commit, opts \\ []) do
    DB.one(DBQueryable.query({__MODULE__, :ancestors_count_query}, [repo, commit], opts))
  end

  @doc """
  Returns the commit history starting from the given `commit`.
  """
  @spec history(Repo.t | pos_integer, Commit.t | Git.oid, keyword) :: [Commit.t]
  def history(repo, commit, opts \\ []) do
    DB.all(DBQueryable.query({__MODULE__, :history_query}, [repo, commit], opts))
  end

  @doc """
  Returns the GPG key associated to given signed `commit`.
  """
  @spec gpg_signature(Repo.t | pos_integer, Commit.t | Git.oid | [Commit.t | Git.oid], keyword) :: GPGKey.t | map
  def gpg_signature(repo, commit, opts \\ [])
  def gpg_signature(repo, commits, opts) when is_list(commits) do
    Map.new(DB.all(DBQueryable.query({__MODULE__, :gpg_signature_query}, [repo, commits], opts)))
  end

  def gpg_signature(repo, commit, opts) do
    DB.one(DBQueryable.query({__MODULE__, :gpg_signature_query}, [repo, commit], opts))
  end

  @doc """
  Returns a query for fetching the commit with the given `oid`.
  """
  @spec commit_query(Repo.t | pos_integer, Git.oid) :: Ecto.Query
  def commit_query(%Repo{id: repo_id}, oid), do: commit_query(repo_id, oid)
  def commit_query(repo_id, oid) when is_integer(repo_id) and is_binary(oid) do
    from(c in Commit, where: c.oid == ^oid)
  end

  @doc """
  Returns a query for counting the number of ancestors for the given `commit`.
  """
  @spec ancestors_count_query(Repo.t | pos_integer, Commit.t | Git.oid) :: Ecto.Query
  def ancestors_count_query(%Repo{id: repo_id} = _repo, %Commit{oid: oid} = _commit), do: ancestors_count_query(repo_id, oid)
  def ancestors_count_query(%Repo{id: repo_id}, oid), do: ancestors_count_query(repo_id, oid)
  def ancestors_count_query(repo_id, %Commit{oid: oid}), do: ancestors_count_query(repo_id, oid)
  def ancestors_count_query(repo_id, oid) when is_integer(repo_id) and is_binary(oid) do
    Commit
    |> join(:inner, [c], f in fragment("commits_dag_desc(?, ?)", ^repo_id, ^oid), on: c.oid == f.oid)
    |> select([c], count(c.oid))
  end

  @doc """
  Returns a query for fetching the commit history starting from the given `commit`.
  """
  @spec history_query(Repo.t | pos_integer, Commit.t | Git.oid) :: Ecto.Query
  def history_query(%Repo{id: repo_id} = _repo, %Commit{oid: oid} = _commit), do: history_query(repo_id, oid)
  def history_query(%Repo{id: repo_id}, oid), do: history_query(repo_id, oid)
  def history_query(repo_id, %Commit{oid: oid}), do: history_query(repo_id, oid)
  def history_query(repo_id, oid) when is_integer(repo_id) and is_binary(oid) do
    Commit
    |> join(:inner, [c], f in fragment("commits_dag_desc(?, ?)", ^repo_id, ^oid), on: c.oid == f.oid)
    |> order_by([c], [desc: :committed_at])
  end

  @doc """
  Returns a query for fetching the GPG key associated to the given signed `commit`.
  """
  @spec gpg_signature_query(Repo.t | pos_integer, Commit.t | Git.oid | [Commit.t | Git.oid]) :: Ecto.Query
  def gpg_signature_query(%Repo{id: repo_id} = _repo, commit), do: gpg_signature_query(repo_id, commit)
  def gpg_signature_query(repo_id, commits) when is_list(commits) do
    oids =
      cond do
        Enum.all?(commits, &is_binary/1) ->
          commits
        Enum.all?(commits, fn %Commit{} -> true end) ->
          Enum.map(commits, &(&1.oid))
      end
    from(c in Commit, join: g in GPGKey, on: c.gpg_key_id == fragment("substring(?, 13, 8)", g.key_id), where: c.repo_id == ^repo_id and c.oid in ^oids, select: {c.oid, g})
  end

  def gpg_signature_query(repo_id, oid) when is_binary(oid) do
    from(c in Commit, join: g in GPGKey, on: c.gpg_key_id == fragment("substring(?, 13, 8)", g.key_id), where: c.repo_id == ^repo_id and c.oid == ^oid, select: g)
  end

  def gpg_signature_query(repo_id, %Commit{} = commit) when is_map(commit) do
    from(c in Commit, join: g in GPGKey, on: c.gpg_key_id == fragment("substring(?, 13, 8)", g.key_id), where: c.repo_id == ^repo_id and c.oid == ^commit.oid, select: g)
  end

  #
  # Callbacks
  #

  @impl true
  def alter_query(query, _preloads, _viewer), do: query
end
