defmodule GitGud.Web.MaintainerController do

  use GitGud.Web, :controller

  alias GitGud.Repo
  alias GitGud.Maintainer

  alias GitGud.UserQuery
  alias GitGud.RepoQuery

  plug :ensure_authenticated

  plug :put_layout, :repo_settings

  action_fallback GitGud.Web.FallbackController

  @doc """
  Renders maintainers.
  """
  @spec edit(Plug.Conn.t, map) :: Plug.Conn.t
  def edit(conn, %{"user_name" => user_name, "repo_name" => repo_name} = _params) do
    if repo = RepoQuery.user_repo(user_name, repo_name, viewer: current_user(conn), preload: :maintainers) do
      if authorized?(current_user(conn), repo, :admin) do
        changeset = Maintainer.changeset(%Maintainer{})
        render(conn, "edit.html", repo: repo, maintainers: Repo.maintainers(repo), changeset: changeset)
      end || {:error, :unauthorized}
    end  || {:error, :not_found}
  end

  @doc """
  Creates a new maintainer.
  """
  @spec create(Plug.Conn.t, map) :: Plug.Conn.t
  def create(conn, %{"user_name" => user_name, "repo_name" => repo_name, "maintainer" => maintainer_params} = _params) do
    if repo = RepoQuery.user_repo(user_name, repo_name, viewer: current_user(conn), preload: :maintainers) do
      if authorized?(current_user(conn), repo, :admin) do
        maintainer_params = Map.update(maintainer_params, "user_id", "", &parse_id/1)
        case Maintainer.create(Map.put(maintainer_params, "repo_id", repo.id)) do
          {:ok, maintainer} ->
            user = UserQuery.by_id(maintainer.user_id)
            conn
            |> put_flash(:info, "Maintainer '#{user.login}' added.")
            |> redirect(to: Routes.maintainer_path(conn, :edit, user_name, repo_name))
          {:error, changeset} ->
            conn
            |> put_flash(:error, "Something went wrong! Please check error(s) below.")
            |> put_status(:bad_request)
            |> render("edit.html", repo: repo, maintainers: Repo.maintainers(repo), changeset: %{changeset|action: :insert})
        end
      end || {:error, :unauthorized}
    end || {:error, :not_found}
  end

  @doc """
  Updates a maintainer's permissions.
  """
  @spec update(Plug.Conn.t, map) :: Plug.Conn.t
  def update(conn, %{"user_name" => user_name, "repo_name" => repo_name, "maintainer" => maintainer_params} = _params) do
    if repo = RepoQuery.user_repo(user_name, repo_name, viewer: current_user(conn), preload: :maintainers) do
      if authorized?(current_user(conn), repo, :admin) do
        maintainer_id = String.to_integer(maintainer_params["id"])
        if maintainer = Enum.find(Repo.maintainers(repo), &(&1.id == maintainer_id)) do
          if maintainer.permission != maintainer_params["permission"] do
            maintainer = Maintainer.update_permission!(maintainer, maintainer_params["permission"])
            conn
            |> put_flash(:info, "Maintainer '#{maintainer.user.login}' permission set to '#{maintainer.permission}'.")
            |> redirect(to: Routes.maintainer_path(conn, :edit, user_name, repo_name))
          else
            conn
            |> put_flash(:info, "Maintainer '#{maintainer.user.login}' permission already set to '#{maintainer.permission}'.")
            |> redirect(to: Routes.maintainer_path(conn, :edit, user_name, repo_name))
          end
        end || {:error, :bad_request}
      end || {:error, :unauthorized}
    end || {:error, :not_found}
  end

  @doc """
  Deletes a maintainer.
  """
  @spec delete(Plug.Conn.t, map) :: Plug.Conn.t
  def delete(conn, %{"user_name" => user_name, "repo_name" => repo_name, "maintainer" => maintainer_params} = _params) do
    if repo = RepoQuery.user_repo(user_name, repo_name, viewer: current_user(conn), preload: :maintainers) do
      if authorized?(current_user(conn), repo, :admin) do
        maintainer_id = String.to_integer(maintainer_params["id"])
        if maintainer = Enum.find(Repo.maintainers(repo), &(&1.id == maintainer_id)) do
          maintainer = Maintainer.delete!(maintainer)
          conn
          |> put_flash(:info, "Maintainer '#{maintainer.user.login}' deleted.")
          |> redirect(to: Routes.maintainer_path(conn, :edit, user_name, repo_name))
        end || {:error, :bad_request}
      end || {:error, :unauthorized}
    end || {:error, :not_found}
  end

  #
  # Helpers
  #

  defp parse_id(str) do
    case Integer.parse(str) do
      {user_id, ""} -> user_id
      :error -> from_relay_id(str)
    end
  end
end
