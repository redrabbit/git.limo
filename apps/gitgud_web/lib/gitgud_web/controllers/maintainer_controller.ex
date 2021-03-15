defmodule GitGud.Web.MaintainerController do
  @moduledoc """
  Module responsible for CRUD actions on `GitGud.Maintainer`.
  """

  use GitGud.Web, :controller

  alias GitGud.Maintainer

  alias GitGud.UserQuery
  alias GitGud.RepoQuery

  plug :ensure_authenticated
  plug :scrub_params, "maintainer" when action in [:create, :update, :delete]

  plug :put_layout, :repo_settings

  action_fallback GitGud.Web.FallbackController

  @doc """
  Renders maintainers.
  """
  @spec index(Plug.Conn.t, map) :: Plug.Conn.t
  def index(conn, %{"user_login" => user_login, "repo_name" => repo_name} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn), preload: :maintainers) do
      if authorized?(conn, repo, :admin) do
        changeset = Maintainer.changeset(%Maintainer{})
        render(conn, "index.html", repo: repo, maintainers: RepoQuery.maintainers(repo), changeset: changeset)
      end || {:error, :unauthorized}
    end  || {:error, :not_found}
  end

  @doc """
  Creates a new maintainer.
  """
  @spec create(Plug.Conn.t, map) :: Plug.Conn.t
  def create(conn, %{"user_login" => user_login, "repo_name" => repo_name, "maintainer" => maintainer_params} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn), preload: :maintainers) do
      if authorized?(conn, repo, :admin) do
        {maintainer_login, other_params} = Map.pop(maintainer_params, "user_login")
        if user = maintainer_login && UserQuery.by_login(maintainer_login) do
          case Maintainer.create(Map.merge(other_params, %{"repo_id" => repo.id, "user_id" => user.id})) do
            {:ok, _maintainer} ->
              conn
              |> put_flash(:info, "Maintainer '#{user.login}' added.")
              |> redirect(to: Routes.maintainer_path(conn, :index, user_login, repo_name))
            {:error, changeset} ->
              {user_error, errors} = Keyword.pop(changeset.errors, :user_id)
              changeset = if user_error, do: %{changeset|errors: [{:user_login, user_error}|errors]}, else: changeset
              conn
              |> put_flash(:error, "Something went wrong! Please check error(s) below.")
              |> put_status(:bad_request)
              |> render("index.html", repo: repo, maintainers: RepoQuery.maintainers(repo), changeset: %{changeset|action: :insert, params: maintainer_params})
          end
        else
          changeset = Maintainer.changeset(%Maintainer{}, maintainer_params)
          changeset = Ecto.Changeset.add_error(changeset, :user_login, is_nil(maintainer_login) && "can't be blank" || "invalid")
          conn
          |> put_flash(:error, "Something went wrong! Please check error(s) below.")
          |> put_status(:bad_request)
          |> render("index.html", repo: repo, maintainers: RepoQuery.maintainers(repo), changeset: %{changeset|action: :insert})
        end
      end || {:error, :unauthorized}
    end || {:error, :not_found}
  end

  @doc """
  Updates a maintainer's permissions.
  """
  @spec update(Plug.Conn.t, map) :: Plug.Conn.t
  def update(conn, %{"user_login" => user_login, "repo_name" => repo_name, "maintainer" => maintainer_params} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn), preload: :maintainers) do
      if authorized?(conn, repo, :admin) do
        maintainer_id = String.to_integer(maintainer_params["id"])
        if maintainer = Enum.find(RepoQuery.maintainers(repo), &(&1.id == maintainer_id)) do
          if maintainer.user_id != repo.owner_id do
            if maintainer.permission != maintainer_params["permission"] do
              maintainer = Maintainer.update_permission!(maintainer, maintainer_params["permission"])
              conn
              |> put_flash(:info, "Maintainer '#{maintainer.user.login}' permission set to '#{maintainer.permission}'.")
              |> redirect(to: Routes.maintainer_path(conn, :index, user_login, repo_name))
            else
              conn
              |> put_flash(:info, "Maintainer '#{maintainer.user.login}' permission already set to '#{maintainer.permission}'.")
              |> redirect(to: Routes.maintainer_path(conn, :index, user_login, repo_name))
            end
          end
        end || {:error, :bad_request}
      end || {:error, :unauthorized}
    end || {:error, :not_found}
  end

  @doc """
  Deletes a maintainer.
  """
  @spec delete(Plug.Conn.t, map) :: Plug.Conn.t
  def delete(conn, %{"user_login" => user_login, "repo_name" => repo_name, "maintainer" => maintainer_params} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn), preload: :maintainers) do
      if authorized?(conn, repo, :admin) do
        maintainer_id = String.to_integer(maintainer_params["id"])
        if maintainer = Enum.find(RepoQuery.maintainers(repo), &(&1.id == maintainer_id)) do
          maintainer = Maintainer.delete!(maintainer)
          conn
          |> put_flash(:info, "Maintainer '#{maintainer.user.login}' deleted.")
          |> redirect(to: Routes.maintainer_path(conn, :index, user_login, repo_name))
        end || {:error, :bad_request}
      end || {:error, :unauthorized}
    end || {:error, :not_found}
  end
end
