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

  @type user_param :: User.t() | binary | pos_integer

  @doc """
  Returns a repository for the given `id`.
  """
  @spec by_id(pos_integer, keyword) :: Repo.t() | nil
  @spec by_id([pos_integer], keyword) :: [Repo.t()]
  def by_id(id, opts \\ [])

  def by_id(ids, opts) when is_list(ids) do
    DB.all(DBQueryable.query({__MODULE__, :repos_query}, [ids], opts))
  end

  def by_id(id, opts) do
    DB.one(DBQueryable.query({__MODULE__, :repo_query}, id, opts))
  end

  @doc """
  Returns a list of repositories for the given `user`.
  """
  @spec user_repos(user_param, keyword) :: [Repo.t()]
  @spec user_repos([user_param], keyword) :: [Repo.t()]
  def user_repos(user, opts \\ [])

  def user_repos(users, opts) when is_list(users) do
    DB.all(DBQueryable.query({__MODULE__, :user_repos_query}, [users], opts))
  end

  def user_repos(user, opts) do
    DB.all(DBQueryable.query({__MODULE__, :user_repos_query}, user, opts))
  end

  @doc """
  Returns a single repository for the given `user` and `name`.
  """
  @spec user_repo(user_param, binary, keyword) :: Repo.t() | nil
  def user_repo(user, name, opts \\ [])

  def user_repo(user, name, opts) do
    DB.one(DBQueryable.query({__MODULE__, :user_repo_query}, [user, name], opts))
  end

  @doc """
  Returns a repository for the given `path`.
  """
  @spec by_path(Path.t(), keyword) :: Repo.t() | nil
  def by_path(path, opts \\ []) do
    path = Path.relative_to(path, Repo.root_path())

    case Path.split(path) do
      [username, name] ->
        user_repo(username, name, opts)

      _path ->
        nil
    end
  end

  @doc """
  Returns a query for fetching a single repository by `id`.
  """
  @spec repo_query(pos_integer) :: Ecto.Query.t()
  def repo_query(id) when is_integer(id) do
    from(r in Repo, join: u in assoc(r, :owner), where: r.id == ^id, preload: [owner: u])
  end

  @doc """
  Returns a query for fetching a repositories by `ids`.
  """
  @spec repos_query([pos_integer]) :: Ecto.Query.t()
  def repos_query(ids) when is_list(ids) do
    from(r in Repo, join: u in assoc(r, :owner), where: r.id in ^ids, preload: [owner: u])
  end

  @doc """
  Returns a query for fetching a single repository for the given `user` and `name`.
  """
  @spec user_repo_query(user_param, binary) :: Ecto.Query.t()
  def user_repo_query(user, name) do
    where(user_repos_query(user), name: ^name)
  end

  @doc """
  Returns a query for fetching user repositories.
  """
  @spec user_repos_query(user_param) :: Ecto.Query.t()
  @spec user_repos_query([user_param]) :: Ecto.Query.t()
  def user_repos_query(%User{id: user_id} = _user), do: user_repos_query(user_id)

  def user_repos_query(username) when is_binary(username) do
    from(r in Repo,
      join: u in assoc(r, :owner),
      where: u.username == ^username,
      preload: [owner: u]
    )
  end

  def user_repos_query(user_id) when is_integer(user_id) do
    from(r in Repo, join: u in assoc(r, :owner), where: u.id == ^user_id, preload: [owner: u])
  end

  def user_repos_query(users) when is_list(users) do
    cond do
      Enum.all?(users, &is_binary/1) ->
        from(r in Repo,
          join: u in assoc(r, :owner),
          where: u.username in ^users,
          preload: [owner: u]
        )

      Enum.all?(users, &is_integer/1) ->
        from(r in Repo, join: u in assoc(r, :owner), where: u.id in ^users, preload: [owner: u])

      Enum.all?(users, &is_map/1) ->
        user_ids = Enum.map(users, &Map.fetch!(&1, :id))

        from(r in Repo,
          join: u in assoc(r, :owner),
          where: u.username in ^user_ids,
          preload: [owner: u]
        )
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
