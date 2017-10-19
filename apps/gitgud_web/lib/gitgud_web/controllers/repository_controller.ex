defmodule GitGud.Web.RepositoryController do
  @moduledoc false
  use GitGud.Web, :controller

  alias GitGud.User
  alias GitGud.UserQuerySet

  alias GitGud.Repository
  alias GitGud.RepositoryQuerySet

  plug :ensure_authenticated when action in [:create, :update, :delete]

  action_fallback GitGud.Web.FallbackController

  def index(conn, %{"user" => username}) do
    repos = RepositoryQuerySet.user_repositories(username)
    render(conn, "index.json", repositories: repos)
  end

  def show(conn, %{"user" => username, "repo" => path}) do
    with user when not is_nil(user) <- UserQuerySet.get(username),
         repo when not is_nil(repo) <- RepositoryQuerySet.user_repository(user, path),
         true <- Repository.can_read?(user, repo) do
      render(conn, "show.json", repository: repo)
    else
      nil -> {:error, :not_found}
      false -> {:error, :unauthorized}
    end
  end

  def create(conn, %{"repository" => repo_params}) do
    repo_params = Map.put(repo_params, "owner_id", conn.assigns.user.id)
    case Repository.create(repo_params) do
      {:ok, repo, _pid} ->
        repo = struct(repo, owner: conn.assigns.user)
        conn
        |> put_status(:created)
        |> put_resp_header("location", repository_path(conn, :show, repo.owner.username, repo.path))
        |> render("show.json", repository: repo)
      {:error, reason} ->
        {:error, reason}
    end
  end

  def update(conn, %{"user" => username, "repo" => path, "repository" => repo_params}) do
    repo_params = Map.delete(repo_params, "owner_id")
    with {:ok, repo} <- fetch_and_ensure_owner({username, path}, conn.assigns[:user]),
         {:ok, repo} <- Repository.update(repo, repo_params), do:
      render(conn, "show.json", repository: repo)
  end

  def delete(conn, %{"user" => username, "repo" => path}) do
    with {:ok, repo} <- fetch_and_ensure_owner({username, path}, conn.assigns[:user]),
         {:ok, _del} <- Repository.delete(repo), do:
      send_resp(conn, :no_content, "")
  end

  #
  # Helpers
  #

  defp fetch_and_ensure_owner({username, path}, %User{username: username}) do
    if repository = RepositoryQuerySet.user_repository(username, path),
      do: {:ok, repository},
    else: {:error, :not_found}
  end

  defp fetch_and_ensure_owner(_repo, _user), do: {:error, :unauthorized}
end
