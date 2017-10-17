defmodule GitGud.Web.RepositoryController do
  @moduledoc false
  use GitGud.Web, :controller

  import Ecto.Query, only: [from: 2, where: 2]

  alias GitGud.Repo
  alias GitGud.Repository

  plug :ensure_authenticated when action in [:create, :update, :delete]

  action_fallback GitGud.Web.FallbackController

  def index(conn, %{"user" => username}) do
    repositories = user_repositories(username)
    render(conn, "index.json", repositories: repositories)
  end

  def create(conn, %{"repository" => repository_params}) do
    with {:ok, repository, _pid} <- Repository.create(repository_params) do
      repository = Repo.preload(repository, :owner)
      conn
      |> put_status(:created)
      |> put_resp_header("location", repository_path(conn, :show, repository.owner.username, repository.path))
      |> render("show.json", repository: repository)
    end
  end

  def show(conn, %{"user" => username, "repo" => path}) do
    repository = user_repository(username, path)
    render(conn, "show.json", repository: repository)
  end

  def update(conn, %{"user" => username, "repo" => path, "repository" => repository_params}) do
    repository = user_repository(username, path)
    with {:ok, repository} <- Repository.update(repository, repository_params) do
      render(conn, "show.json", repository: repository)
    end
  end

  def delete(conn, %{"user" => username, "repo" => path}) do
    repository = user_repository(username, path)
    with {:ok, _repository} <- Repository.delete(repository) do
      send_resp(conn, :no_content, "")
    end
  end

  #
  # Helpers
  #

  defp user_repositories(username) do
    Repo.all(repo_query(username))
  end

  defp user_repository(username, path) do
    Repo.one(repo_query(username, path))
  end

  defp repo_query(username) do
    from(r in Repository, join: u in assoc(r, :owner), where: u.username == ^username, preload: [owner: u])
  end

  defp repo_query(username, path) do
    where(repo_query(username), path: ^path)
  end
end
