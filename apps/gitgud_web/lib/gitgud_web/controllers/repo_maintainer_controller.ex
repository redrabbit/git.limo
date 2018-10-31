defmodule GitGud.Web.RepoMaintainerController do

  use GitGud.Web, :controller

  alias GitGud.Repo
  alias GitGud.RepoMaintainer

  alias GitGud.UserQuery
  alias GitGud.RepoQuery

  plug :ensure_authenticated

  plug :put_layout, :repo_settings

  action_fallback GitGud.Web.FallbackController

  @doc """
  Renders maintainers.
  """
  @spec index(Plug.Conn.t, map) :: Plug.Conn.t
  def index(conn, %{"username" => username, "repo_name" => repo_name} = _params) do
    if repo = RepoQuery.user_repo(username, repo_name, viewer: current_user(conn), preload: :maintainers) do
      if authorized?(current_user(conn), repo, :admin) do
        changeset = RepoMaintainer.changeset(%RepoMaintainer{})
        render(conn, "index.html", repo: repo, maintainers: Repo.maintainers(repo), changeset: changeset)
      end || {:error, :unauthorized}
    end  || {:error, :not_found}
  end

  @doc """
  Creates a new maintainer.
  """
  @spec create(Plug.Conn.t, map) :: Plug.Conn.t
  def create(conn, %{"username" => username, "repo_name" => repo_name, "maintainer" => maintainer_params} = _params) do
    if repo = RepoQuery.user_repo(username, repo_name, viewer: current_user(conn), preload: :maintainers) do
      if authorized?(current_user(conn), repo, :admin) do
        maintainer_params = Map.update(maintainer_params, "user_id", "", &from_relay_id/1)
        case RepoMaintainer.create(Map.put(maintainer_params, "repo_id", repo.id)) do
          {:ok, maintainer} ->
            user = UserQuery.by_id(maintainer.user_id)
            conn
            |> put_flash(:info, "Maintainer '#{user.username}' added.")
            |> redirect(to: Routes.repo_maintainer_path(conn, :index, username, repo_name))
          {:error, changeset} ->
            IO.inspect changeset
            conn
            |> put_flash(:error, "Something went wrong! Please check error(s) below.")
            |> put_status(:bad_request)
            |> render("index.html", repo: repo, maintainers: Repo.maintainers(repo), changeset: %{changeset|action: :insert})
        end
      end || {:error, :unauthorized}
    end || {:error, :not_found}
  end

  @doc """
  Updates a maintainer's permissions.
  """
  @spec update(Plug.Conn.t, map) :: Plug.Conn.t
  def update(conn, %{"username" => username, "repo_name" => repo_name, "maintainer" => maintainer_params} = _params) do
    if repo = RepoQuery.user_repo(username, repo_name, viewer: current_user(conn), preload: :maintainers) do
      if authorized?(current_user(conn), repo, :admin) do
        maintainer_id = String.to_integer(maintainer_params["id"])
        if maintainer = Enum.find(Repo.maintainers(repo), &(&1.id == maintainer_id)) do
          if maintainer.permission != maintainer_params["permission"] do
            maintainer = RepoMaintainer.update_permission!(maintainer, maintainer_params["permission"])
            conn
            |> put_flash(:info, "Maintainer '#{maintainer.user.username}' permission set to '#{maintainer.permission}'.")
            |> redirect(to: Routes.repo_maintainer_path(conn, :index, username, repo_name))
          else
            conn
            |> put_flash(:info, "Maintainer '#{maintainer.user.username}' permission already set to '#{maintainer.permission}'.")
            |> redirect(to: Routes.repo_maintainer_path(conn, :index, username, repo_name))
          end
        end || {:error, :bad_request}
      end || {:error, :unauthorized}
    end || {:error, :not_found}
  end

  @doc """
  Deletes a maintainer.
  """
  @spec delete(Plug.Conn.t, map) :: Plug.Conn.t
  def delete(conn, %{"username" => username, "repo_name" => repo_name, "maintainer" => maintainer_params} = _params) do
    if repo = RepoQuery.user_repo(username, repo_name, viewer: current_user(conn), preload: :maintainers) do
      if authorized?(current_user(conn), repo, :admin) do
        maintainer_id = String.to_integer(maintainer_params["id"])
        if maintainer = Enum.find(Repo.maintainers(repo), &(&1.id == maintainer_id)) do
          maintainer = RepoMaintainer.delete!(maintainer)
          conn
          |> put_flash(:info, "Maintainer '#{maintainer.user.username}' deleted.")
          |> redirect(to: Routes.repo_maintainer_path(conn, :index, username, repo_name))
        end || {:error, :bad_request}
      end || {:error, :unauthorized}
    end || {:error, :not_found}
  end
end
