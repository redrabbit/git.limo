defmodule GitGud.RepoQuery do
  @moduledoc """
  Conveniences for `GitGud.Repo` related queries.
  """

  @behaviour GitGud.DBQueryable

  alias GitGud.DB
  alias GitGud.DBQueryable

  alias GitGud.Repo
  alias GitGud.User

  import Ecto.Query

  @doc """
  Returns a repository for the given `id`.
  """
  @spec by_id(pos_integer, keyword) :: Repo.t | nil
  def by_id(id, opts \\ []) do
    DB.one(DBQueryable.query({__MODULE__, :query}, id, opts))
  end

  @doc """
  Returns a list of repositories for the given `user`.
  """
  @spec user_repositories(User.t|binary, keyword) :: [Repo.t]
  def user_repositories(user, opts \\ [])
  def user_repositories(%User{} = user, opts) do
    DB.all(DBQueryable.query({__MODULE__, :query}, user, opts))
  end

  def user_repositories(username, opts) when is_binary(username) do
    DB.all(DBQueryable.query({__MODULE__, :query}, username, opts))
  end

  @doc """
  Returns a single repository for the given `user` and `name`.
  """
  @spec user_repository(User.t|binary, binary, keyword) :: Repo.t | nil
  def user_repository(user, name, opts \\ [])
  def user_repository(%User{} = user, name, opts) do
    DB.one(DBQueryable.query({__MODULE__, :query}, {user, name}, opts))
  end

  def user_repository(username, name, opts) when is_binary(username) do
    DB.one(DBQueryable.query({__MODULE__, :query}, {username, name}, opts))
  end

  @doc """
  Returns a repository for the given `path`.
  """
  @spec by_path(Path.t, keyword) :: Repo.t | nil
  def by_path(path, opts \\ []) do
    path = Path.relative_to(path, Repo.root_path())
    case Path.split(path) do
      [username, name] ->
        user_repository(username, name, opts)
      _path ->
        nil
    end
  end

  @doc """
  Returns a query for fetching repositories.
  """
  @spec query(User.t) :: Ecto.Query.t
  def query(%User{id: user_id} = _arg) do
    from(r in Repo, join: u in assoc(r, :owner), where: u.id == ^user_id, preload: [owner: u])
  end

  @spec query(pos_integer) :: Ecto.Query.t
  def query(id) when is_integer(id) do
    from(r in Repo, join: u in assoc(r, :owner), where: r.id == ^id, preload: [owner: u])
  end

  @spec query(binary) :: Ecto.Query.t
  def query(username) when is_binary(username) do
    from(r in Repo, join: u in assoc(r, :owner), where: u.username == ^username, preload: [owner: u])
  end

  @spec query({User.t | binary, binary}) :: Ecto.Query.t
  def query({user, name}) do
    where(query(user), name: ^name)
  end

  #
  # Callbacks
  #

  @impl true
  def alter_query(query, preloads, nil) do
    query
    |> where([r, u], r.public == true)
    |> preload([r, u], ^preloads)
  end

  @impl true
  def alter_query(query, preloads, viewer) do
    query
    |> join(:left, [r, u], m in "repositories_maintainers", r.id == m.repo_id)
    |> where([r, u, m], r.public == true or r.owner_id == ^viewer.id or m.user_id == ^viewer.id)
    |> preload([r, u], ^preloads)
  end
end
