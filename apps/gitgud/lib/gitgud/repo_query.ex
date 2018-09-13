defmodule GitGud.RepoQuery do
  @moduledoc """
  Conveniences for `GitGud.Repo` related queries.
  """

  alias GitGud.DB
  alias GitGud.Repo
  alias GitGud.User

  import Ecto.Query, only: [from: 2, where: 2]

  @doc """
  Returns a list of repositories for the given `user`.

  If `user` is a `binary`, this function assumes that it represent a username
  and uses it as such as part of the query.
  """
  @spec user_repositories(User.t|binary) :: [Repo.t]
  def user_repositories(%User{} = user) do
    user
    |> repo_query()
    |> DB.all()
    |> Enum.map(&put_owner(&1, user))
  end

  def user_repositories(username) when is_binary(username) do
    DB.all(repo_query(username))
  end

  @doc """
  Returns a single user repository for the given `user` and `name`.

  If `user` is a `binary`, this function assumes that it represent a username
  and uses it as such as part of the query.
  """
  @spec user_repository(User.t|binary, binary) :: Repo.t | nil
  def user_repository(%User{} = user, name) do
    user
    |> repo_query(name)
    |> DB.one()
    |> put_owner(user)
  end

  def user_repository(username, name) when is_binary(username) do
    DB.one(repo_query(username, name))
  end

  @doc """
  Returns a repository for the given `id`.
  """
  @spec by_id(pos_integer) :: Repo.t | nil
  def by_id(id) do
    DB.one(repo_query(id))
  end

  @doc """
  Returns a repository for the given `path`.
  """
  @spec by_path(Path.t) :: Repo.t | nil
  def by_path(path) do
    root = Application.fetch_env!(:gitgud, :git_dir)
    path = if Path.type(path) == :absolute, do: Path.relative_to(path, root), else: path
    apply(__MODULE__, :user_repository, Path.split(path))
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

  defp repo_query(user, name) do
    where(repo_query(user), name: ^name)
  end

  defp put_owner(nil, %User{}), do: nil
  defp put_owner(%Repo{} = repo, %User{} = user), do: struct(repo, owner: user)
end
