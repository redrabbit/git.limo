defmodule GitGud.RepoQuery do
  @moduledoc """
  Conveniences for `GitGud.Repo` related queries.
  """

  alias GitGud.QuerySet
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
    |> QuerySet.all()
    |> Enum.map(&put_owner(&1, user))
  end

  def user_repositories(username) when is_binary(username) do
    QuerySet.all(repo_query(username))
  end

  @doc """
  Returns a single user repository for the given `user` and `path`.

  If `user` is a `binary`, this function assumes that it represent a username
  and uses it as such as part of the query.
  """
  @spec user_repository(User.t|binary, Path.t) :: Repo.t | nil
  def user_repository(%User{} = user, path) do
    user
    |> repo_query(path)
    |> QuerySet.one()
    |> put_owner(user)
  end

  def user_repository(username, path) when is_binary(username) do
    QuerySet.one(repo_query(username, path))
  end

  #
  # Helpers
  #

  defp repo_query(%User{id: user_id}) do
    where(Repo, owner_id: ^user_id)
  end

  defp repo_query(username) when is_binary(username) do
    from(r in Repo, join: u in assoc(r, :owner), where: u.username == ^username, preload: [owner: u])
  end

  defp repo_query(user, path) do
    where(repo_query(user), path: ^path)
  end

  defp put_owner(%Repo{} = repo, %User{} = user), do: struct(repo, owner: user)
  defp put_owner(repo, %User{}) when is_nil(repo), do: repo
end
