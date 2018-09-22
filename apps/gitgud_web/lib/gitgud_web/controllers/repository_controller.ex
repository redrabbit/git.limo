defmodule GitGud.Web.RepositoryController do
  @moduledoc """
  Module responsible for user registration.
  """

  use GitGud.Web, :controller

  alias GitGud.Repo
  alias GitGud.RepoQuery

  plug :ensure_authenticated
  plug :put_layout, :repository_layout when action not in [:new]

  action_fallback GitGud.Web.FallbackController

  @doc """
  Renders a repository creation form.
  """
  @spec new(Plug.Conn.t, map) :: Plug.Conn.t
  def new(conn, %{} = _params) do
    changeset = Repo.changeset(%Repo{})
    render(conn, "new.html", changeset: changeset)
  end

  @doc """
  Creates a new repository.
  """
  @spec create(Plug.Conn.t, map) :: Plug.Conn.t
  def create(conn, %{"repo" => repo_params} = _params) do
    user = current_user(conn)
    case Repo.create(Map.put(repo_params, "owner_id", user.id)) do
      {:ok, repo, _handle} ->
        conn
        |> put_flash(:info, "Repository created.")
        |> redirect(to: codebase_path(conn, :show, user, repo))
      {:error, changeset} ->
        conn
        |> put_flash(:error, "Something went wrong! Please check error(s) below.")
        |> render("new.html", changeset: %{changeset|action: :insert})
    end
  end

  @doc """
  Renders a repository edit form.
  """
  @spec edit(Plug.Conn.t, map) :: Plug.Conn.t
  def edit(conn, %{"username" => username, "repo_name" => repo_name} = _params) do
    if repo = RepoQuery.user_repository(username, repo_name, viewer: current_user(conn), preload: :maintainers) do
      if authorized?(current_user(conn), repo, :edit) do
        changeset = Repo.changeset(repo)
        render(conn, "edit.html", repo: repo, changeset: changeset)
      end || {:error, :unauthorized}
    end   || {:error, :not_found}
  end

  @doc """
  Updates a repository.
  """
  @spec update(Plug.Conn.t, map) :: Plug.Conn.t
  def update(conn, %{"username" => username, "repo_name" => repo_name, "repo" => repo_params} = _params) do
    user = current_user(conn)
    if repo = RepoQuery.user_repository(username, repo_name, viewer: user, preload: :maintainers) do
      if authorized?(user, repo, :edit) do
        case Repo.update(repo, repo_params) do
          {:ok, repo} ->
            conn
            |> put_flash(:info, "Repository updated.")
            |> redirect(to: codebase_path(conn, :show, repo.owner, repo))
          {:error, changeset} ->
            conn
            |> put_flash(:error, "Something went wrong! Please check error(s) below.")
            |> render("edit.html", changeset: %{changeset|action: :insert})
        end
      end || {:error, :unauthorized}
    end   || {:error, :not_found}
  end
end

