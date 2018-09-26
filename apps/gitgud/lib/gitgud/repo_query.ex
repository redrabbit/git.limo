defmodule GitGud.RepoQuery do
  @moduledoc """
  Conveniences for `GitGud.Repo` related queries.
  """

  alias GitGud.DB
  alias GitGud.Repo
  alias GitGud.User

  import Ecto.Query

  @doc """
  Returns a repository for the given `id`.
  """
  @spec by_id(pos_integer, keyword) :: Repo.t | nil
  def by_id(id, opts \\ []) do
    {params, opts} = extract_opts(opts)
    DB.one(repo_query(id, params), opts)
  end

  @doc """
  Returns a list of repositories for the given `user`.
  """
  @spec user_repositories(User.t|binary, keyword) :: [Repo.t]
  def user_repositories(user, opts \\ [])
  def user_repositories(%User{} = user, opts) do
    {params, opts} = extract_opts(opts)
    DB.all(repo_query(user, params), opts)
  end

  def user_repositories(username, opts) when is_binary(username) do
    {params, opts} = extract_opts(opts)
    DB.all(repo_query(username, params), opts)
  end

  @doc """
  Returns a single repository for the given `user` and `name`.
  """
  @spec user_repository(User.t|binary, binary, keyword) :: Repo.t | nil
  def user_repository(user, name, opts \\ [])
  def user_repository(%User{} = user, name, opts) do
    {params, opts} = extract_opts(opts)
    DB.one(repo_query({user, name}, params), opts)
  end

  def user_repository(username, name, opts) when is_binary(username) do
    {params, opts} = extract_opts(opts)
    DB.one(repo_query({username, name}, params), opts)
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

  #
  # Helpers
  #

  defp repo_query(%User{id: user_id}) do
    from(r in Repo, join: u in assoc(r, :owner), where: u.id == ^user_id, preload: [owner: u])
  end

  defp repo_query(id) when is_integer(id) do
    from(r in Repo, join: u in assoc(r, :owner), where: r.id == ^id, preload: [owner: u])
  end

  defp repo_query(username) when is_binary(username) do
    from(r in Repo, join: u in assoc(r, :owner), where: u.username == ^username, preload: [owner: u])
  end

  defp repo_query({user, name}) do
    where(repo_query(user), name: ^name)
  end

  defp repo_query(match, {pagination, preloads, viewer}) do
    match
    |> repo_query()
    |> exec_pagination(pagination)
    |> exec_preload(preloads, viewer)
  end

  defp exec_pagination(query, {nil, nil}), do: query
  defp exec_pagination(query, {offset, nil}), do: offset(query, ^offset)
  defp exec_pagination(query, {nil, limit}), do: limit(query, ^limit)
  defp exec_pagination(query, {offset, limit}) do
    query
    |> offset(^offset)
    |> limit(^limit)
  end

  defp exec_preload(query, preloads, nil) do
    query
    |> where([r, u], r.public == true)
    |> preload([r, u], ^preloads)
  end

  defp exec_preload(query, preloads, viewer) do
    query
    |> join(:left, [r, u], m in "repositories_maintainers", r.id == m.repo_id)
    |> where([r, u, m], r.public == true or r.owner_id == ^viewer.id or m.user_id == ^viewer.id)
    |> preload([r, u], ^preloads)
  end

  defp extract_opts(opts) do
    {offset, opts} = Keyword.pop(opts, :offset)
    {limit, opts} = Keyword.pop(opts, :limit)
    {preloads, opts} = Keyword.pop(opts, :preload, [])
    {viewer, opts} = Keyword.pop(opts, :viewer)
    {{{offset, limit}, List.wrap(preloads), viewer}, opts}
  end
end
