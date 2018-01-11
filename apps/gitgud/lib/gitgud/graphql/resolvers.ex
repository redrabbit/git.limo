defmodule GitGud.GraphQL.Resolvers do

  alias GitGud.UserQuery
  alias GitGud.RepoQuery

  def ecto_loader do
    Dataloader.Ecto.new(GitGud.QuerySet, query: &query/2)
  end

  def resolve_user(%{}, %{username: username}, _info) do
    if user = UserQuery.by_username(username),
      do: {:ok, user},
    else: {:error, "Invalid username #{username}"}
  end

  def resolve_user_repo(user, %{name: name}, _info) do
    if repo = RepoQuery.user_repository(user, name),
    do: {:ok, repo},
    else: {:error, "Invalid repo #{name}"}
  end

  #
  # helpers
  #

  defp query(queryable, _params), do: queryable
end
