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
  @spec by_id([pos_integer], keyword) :: [Repo.t]
  def by_id(id, opts \\ [])
  def by_id(ids, opts) when is_list(ids) do
    DB.all(DBQueryable.query({__MODULE__, :query}, [ids], opts))
  end

  def by_id(id, opts) do
    DB.one(DBQueryable.query({__MODULE__, :query}, id, opts))
  end

  @doc """
  Returns a list of repositories for the given `user`.
  """
  @spec user_repositories(User.t|binary|pos_integer, keyword) :: [Repo.t]
  @spec user_repositories([User.t|binary|pos_integer], keyword) :: [Repo.t]
  def user_repositories(user, opts \\ [])
  def user_repositories(users, opts) when is_list(users) do
    DB.all(DBQueryable.query({__MODULE__, :query}, [users], opts))
  end

  def user_repositories(user, opts) do
    DB.all(DBQueryable.query({__MODULE__, :query}, user, opts))
  end

  @doc """
  Returns a single repository for the given `user` and `name`.
  """
  @spec user_repository(User.t|binary|pos_integer, binary, keyword) :: Repo.t | nil
  def user_repository(user, name, opts \\ [])
  def user_repository(user, name, opts) do
    DB.one(DBQueryable.query({__MODULE__, :query}, {user, name}, opts))
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
  @spec query(User.t | binary | pos_integer) :: Ecto.Query.t
  @spec query([User.t | binary | pos_integer]) :: Ecto.Query.t
  @spec query({User.t | binary | pos_integer, binary}) :: Ecto.Query.t
  def query(%User{id: user_id} = _arg), do: query(user_id)

  def query(username) when is_binary(username) do
    from(r in Repo, join: u in assoc(r, :owner), where: u.username == ^username, preload: [owner: u])
  end

  def query(user_id) when is_integer(user_id) do
    from(r in Repo, join: u in assoc(r, :owner), where: u.id == ^user_id, preload: [owner: u])
  end

  def query({user, name}) do
    where(query(user), name: ^name)
  end

  def query(args) when is_list(args) do
    cond do
      Enum.all?(args, &is_binary/1) ->
        from(r in Repo, join: u in assoc(r, :owner), where: u.username in ^args, preload: [owner: u])
      Enum.all?(args, &is_integer/1) ->
        from(r in Repo, join: u in assoc(r, :owner), where: u.id in ^args, preload: [owner: u])
      Enum.all?(args, &is_map/1) ->
        user_ids = Enum.map(args, &Map.fetch!(&1, :id))
        from(r in Repo, join: u in assoc(r, :owner), where: u.username in ^user_ids, preload: [owner: u])
    end
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
