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

  If `user` is a `binary`, this function assumes that it represent a username
  and uses it as such as part of the query.
  """
  @spec user_repositories(User.t|binary, keyword) :: [Repo.t]
  def user_repositories(user, opts \\ [])
  def user_repositories(%User{} = user, opts) do
    {params, opts} = extract_opts(opts)
    Enum.map(DB.all(repo_query(user, params), opts), &put_owner(&1, user))
  end

  def user_repositories(username, opts) when is_binary(username) do
    {params, opts} = extract_opts(opts)
    DB.all(repo_query(username, params), opts)
  end

  @doc """
  Returns a single user repository for the given `user` and `name`.

  If `user` is a `binary`, this function assumes that it represent a username
  and uses it as such as part of the query.
  """
  @spec user_repository(User.t|binary, binary, keyword) :: Repo.t | nil
  def user_repository(user, name, opts \\ [])
  def user_repository(%User{} = user, name, opts) do
    {params, opts} = extract_opts(opts)
    put_owner(DB.one(repo_query({user, name}, params), opts), user)
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
    root = Path.absname(Application.fetch_env!(:gitgud, :git_root), Application.app_dir(:gitgud))
    path = if Path.type(path) == :absolute,
      do: Path.relative_to(path, root),
    else: path
    apply(__MODULE__, :user_repository, Path.split(path) ++ [opts])
  end

  #
  # Helpers
  #

  defp repo_query(%User{id: user_id}) do
    where(Repo, owner_id: ^user_id)
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

  defp repo_query(match, {preloads, viewer}) do
    exec_preload(repo_query(match), preloads, viewer)
  end

  defp exec_preload(query, preloads, nil) do
    where(query, [r], r.public == true)
  end

  defp exec_preload(query, preloads, viewer) do
    query
    |> join(:left, [r], m in "repositories_maintainers", m.user_id == ^viewer.id)
    |> where([r, m], r.public == true or r.owner_id == ^viewer.id or m.repo_id == r.id)
  end

  defp put_owner(nil, %User{}), do: nil
  defp put_owner(%Repo{} = repo, %User{} = user), do: struct(repo, owner: user)

  defp extract_opts(opts) do
    {preloads, opts} = Keyword.pop(opts, :preload, [])
    {viewer, opts} = Keyword.pop(opts, :viewer)
    {{List.wrap(preloads), viewer}, opts}
  end
end
