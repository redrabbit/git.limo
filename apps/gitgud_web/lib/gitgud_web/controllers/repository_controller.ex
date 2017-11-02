defmodule GitGud.Web.RepositoryController do
  @moduledoc """
  Module responsible for handling CRUD repository requests.
  """

  use GitGud.Web, :controller

  alias GitGud.User
  alias GitGud.UserQuery

  alias GitGud.Repo
  alias GitGud.RepoQuery

  plug :ensure_authenticated when action in [:create, :update, :delete]

  action_fallback GitGud.Web.FallbackController

  @doc """
  Returns all repository for a given user.
  """
  @spec index(Plug.Conn.t, map) :: Plug.Conn.t
  def index(conn, %{"user" => username} = _params) do
    repos = RepoQuery.user_repositories(username)
    render(conn, "index.json", repositories: repos)
  end

  @doc """
  Returns a single repository.
  """
  @spec show(Plug.Conn.t, map) :: Plug.Conn.t
  def show(conn, %{"user" => username, "repo" => path} = _params) do
    with user when not is_nil(user) <- UserQuery.get(username),
         repo when not is_nil(repo) <- RepoQuery.user_repository(user, path),
         true <- Repo.can_read?(user, repo) do
      render(conn, "show.json", repository: repo)
    else
      nil   -> {:error, :not_found}
      false -> {:error, :unauthorized}
    end
  end

  @doc """
  Creates a new repository.
  """
  @spec create(Plug.Conn.t, map) :: Plug.Conn.t
  def create(conn, %{"repository" => repo_params} = _params) do
    repo_params = Map.put(repo_params, "owner_id", conn.assigns.user.id)
    case Repo.create(repo_params) do
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

  @doc """
  Updates an existing repository.
  """
  @spec update(Plug.Conn.t, map) :: Plug.Conn.t
  def update(conn, %{"user" => username, "repo" => path, "repository" => repo_params}) do
    repo_params = Map.delete(repo_params, "owner_id")
    with {:ok, repo} <- fetch_and_ensure_owner({username, path}, conn.assigns[:user]),
         {:ok, repo} <- Repo.update(repo, repo_params), do:
      render(conn, "show.json", repository: repo)
  end

  @doc """
  Deletes an existing repository.
  """
  @spec delete(Plug.Conn.t, map) :: Plug.Conn.t
  def delete(conn, %{"user" => username, "repo" => path} = _params) do
    with {:ok, repo} <- fetch_and_ensure_owner({username, path}, conn.assigns[:user]),
         {:ok, _del} <- Repo.delete(repo), do:
      send_resp(conn, :no_content, "")
  end

  #
  # Helpers
  #

  defp fetch_and_ensure_owner({username, path}, %User{username: username}) do
    if repository = RepoQuery.user_repository(username, path),
      do: {:ok, repository},
    else: {:error, :not_found}
  end

  defp fetch_and_ensure_owner(_repo, _user), do: {:error, :unauthorized}
end
