defmodule GitGud.RepoQuery do
  @moduledoc """
  Conveniences for `GitGud.Repo` related queries.
  """

  alias GitGud.DB
  alias GitGud.Repo
  alias GitGud.User

  import Ecto.Query, only: [from: 2, where: 2, preload: 2]

  @doc """
  Returns a repository for the given `id`.
  """
  @spec by_id(pos_integer, keyword) :: Repo.t | nil
  def by_id(id, opts \\ []) do
    {preloads, opts} = Keyword.pop(opts, :preload, [])
    DB.one(repo_query(id, preloads), opts)
  end

  @doc """
  Returns a list of repositories for the given `user`.

  If `user` is a `binary`, this function assumes that it represent a username
  and uses it as such as part of the query.
  """
  @spec user_repositories(User.t|binary, keyword) :: [Repo.t]
  def user_repositories(user, opts \\ [])
  def user_repositories(%User{} = user, opts) do
    {preloads, opts} = Keyword.pop(opts, :preload, [])
    user
    |> repo_query(preloads)
    |> DB.all(opts)
    |> Enum.map(&put_owner(&1, user))
  end

  def user_repositories(username, opts) when is_binary(username) do
    {preloads, opts} = Keyword.pop(opts, :preload, [])
    DB.all(repo_query(username, preloads), opts)
  end

  @doc """
  Returns a single user repository for the given `user` and `name`.

  If `user` is a `binary`, this function assumes that it represent a username
  and uses it as such as part of the query.
  """
  @spec user_repository(User.t|binary, binary, keyword) :: Repo.t | nil
  def user_repository(user, name, opts \\ [])
  def user_repository(%User{} = user, name, opts) do
    {preloads, opts} = Keyword.pop(opts, :preload, [])
    {user, name}
    |> repo_query(preloads)
    |> DB.one(opts)
    |> put_owner(user)
  end

  def user_repository(username, name, opts) when is_binary(username) do
    {preloads, opts} = Keyword.pop(opts, :preload, [])
    DB.one(repo_query({username, name}, preloads), opts)
  end

  @doc """
  Returns a repository for the given `path`.
  """
  @spec by_path(Path.t, keyword) :: Repo.t | nil
  def by_path(path, opts \\ []) do
    root = Application.fetch_env!(:gitgud, :git_dir)
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

  defp repo_query(match, preloads) do
    preload(repo_query(match), ^preloads)
  end

  defp put_owner(nil, %User{}), do: nil
  defp put_owner(%Repo{} = repo, %User{} = user), do: struct(repo, owner: user)
end
