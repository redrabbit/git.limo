defmodule GitGud.Web.IssueLabelController do
  @moduledoc """
  Module responsible for CRUD actions on `GitGud.IssueLabel`.
  """

  use GitGud.Web, :controller

  alias GitGud.Repo
  alias GitGud.RepoQuery

  plug :ensure_authenticated when action == :update
  plug :put_layout, :repo

  action_fallback GitGud.Web.FallbackController

  @doc """
  Renders issue labels.
  """
  @spec index(Plug.Conn.t, map) :: Plug.Conn.t
  def index(conn, %{"user_login" => user_login, "repo_name" => repo_name} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn), preload: [:issue_labels]),
     do: render(conn, "index.html", repo: repo, changeset: Repo.issue_labels_changeset(repo)),
   else: {:error, :not_found}
  end

  @doc """
  Updates issue labels.
  """
  @spec update(Plug.Conn.t, map) :: Plug.Conn.t
  def update(conn, %{"user_login" => user_login, "repo_name" => repo_name, "repo" => repo_params} = _params) do
    user = current_user(conn)
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn), preload: [:issue_labels]) do
      if authorized?(user, repo, :admin) do
        case Repo.update_issue_labels(repo, repo_params) do
          {:ok, _repo} ->
            conn
            |> put_flash(:info, "Issue labels updated.")
            |> redirect(to: Routes.issue_label_path(conn, :index, user_login, repo_name))
          {:error, changeset} ->
            conn
            |> put_flash(:error, "Something went wrong! Please check error(s) below.")
            |> put_status(:bad_request)
            |> render("index.html", repo: repo, changeset: %{changeset|action: :update})
        end
      end || {:error, :unauthorized}
    end || {:error, :not_found}
  end
end
