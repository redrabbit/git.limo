defmodule GitGud.Web.RepoController do
  @moduledoc """
  Module responsible for CRUD actions on `GitGud.SSHKey`.
  """

  use GitGud.Web, :controller

  alias GitGud.User
  alias GitGud.UserQuery
  alias GitGud.Repo
  alias GitGud.RepoQuery

  plug :ensure_authenticated when action != :index
  plug :put_layout, :user_profile when action == :index
  plug :put_layout, :repo_settings when action in [:edit, :update, :delete]

  action_fallback GitGud.Web.FallbackController

  @doc """
  Renders user repositories.
  """
  @spec index(Plug.Conn.t, map) :: Plug.Conn.t
  def index(conn, %{"user_login" => user_login} = _params) do
    if user = UserQuery.by_login(user_login, preload: [:public_email, :repos], viewer: current_user(conn)),
      do: render(conn, "index.html", user: user),
    else: {:error, :not_found}
  end

  @doc """
  Renders a repository creation form.
  """
  @spec new(Plug.Conn.t, map) :: Plug.Conn.t
  def new(conn, %{} = _params) do
    user = current_user(conn)
    if verified?(user),
      do: render(conn, "new.html", changeset: Repo.changeset(%Repo{})),
    else: {:error, :unauthorized}
  end

  @doc """
  Creates a new repository.
  """
  @spec create(Plug.Conn.t, map) :: Plug.Conn.t
  def create(conn, %{"repo" => repo_params} = _params) do
    user = current_user(conn)
    if verified?(user) do
      case Repo.create(Map.put(repo_params, "owner_id", user.id)) do
        {:ok, repo} ->
          conn
          |> put_flash(:info, "Repository '#{repo.owner.login}/#{repo.name}' created.")
          |> redirect(to: Routes.codebase_path(conn, :show, user, repo))
        {:error, changeset} ->
          conn
          |> put_flash(:error, "Something went wrong! Please check error(s) below.")
          |> put_status(:bad_request)
          |> render("new.html", changeset: %{changeset|action: :insert})
      end
    end || {:error, :unauthorized}
  end

  @doc """
  Renders a repository edit form.
  """
  @spec edit(Plug.Conn.t, map) :: Plug.Conn.t
  def edit(conn, %{"user_login" => user_login, "repo_name" => repo_name} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn), preload: :maintainers) do
      if authorized?(conn, repo, :admin) do
        changeset = Repo.changeset(repo)
        render(conn, "edit.html", repo: repo, changeset: changeset)
      end || {:error, :unauthorized}
    end   || {:error, :not_found}
  end

  @doc """
  Updates a repository.
  """
  @spec update(Plug.Conn.t, map) :: Plug.Conn.t
  def update(conn, %{"user_login" => user_login, "repo_name" => repo_name, "repo" => repo_params} = _params) do
    user = current_user(conn)
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: user, preload: :maintainers) do
      if authorized?(user, repo, :admin) do
        case Repo.update(repo, repo_params) do
          {:ok, repo} ->
            conn
            |> put_flash(:info, "Repository '#{repo.owner.login}/#{repo.name}' updated.")
            |> redirect(to: Routes.repo_path(conn, :edit, repo.owner, repo))
          {:error, changeset} ->
            conn
            |> put_flash(:error, "Something went wrong! Please check error(s) below.")
            |> put_status(:bad_request)
            |> render("edit.html", repo: repo, changeset: %{changeset|action: :insert})
        end
      end || {:error, :unauthorized}
    end   || {:error, :not_found}
  end

  @doc """
  Updates a repository.
  """
  @spec delete(Plug.Conn.t, map) :: Plug.Conn.t
  def delete(conn, %{"user_login" => user_login, "repo_name" => repo_name} = _params) do
    user = current_user(conn)
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: user, preload: :maintainers) do
      if repo.owner_id == user.id do
        repo = Repo.delete!(repo)
        conn
        |> put_flash(:info, "Repository '#{repo.owner.login}/#{repo.name}' deleted.")
        |> redirect(to: Routes.user_path(conn, :show, user))
      end || {:error, :unauthorized}
    end   || {:error, :not_found}
  end
end
