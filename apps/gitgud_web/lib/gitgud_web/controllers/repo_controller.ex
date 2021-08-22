defmodule GitGud.Web.RepoController do
  @moduledoc """
  Module responsible for CRUD actions on `GitGud.SSHKey`.
  """

  use GitGud.Web, :controller

  alias GitRekt.GitAgent

  alias GitGud.UserQuery
  alias GitGud.Repo
  alias GitGud.RepoQuery
  alias GitGud.IssueQuery

  require Logger

  plug :ensure_authenticated when action != :index
  plug :put_layout, :user_profile when action == :index
  plug :put_layout, :repo_settings when action in [:edit, :update, :delete]

  action_fallback GitGud.Web.FallbackController

  @doc """
  Renders user repositories.
  """
  @spec index(Plug.Conn.t, map) :: Plug.Conn.t
  def index(conn, %{"user_login" => user_login} = _params) do
    if user = UserQuery.by_login(user_login, preload: [:public_email, :repos], viewer: current_user(conn)) do
      batch_stats = %{
        contributors: RepoQuery.count_contributors(user.repos),
        issues: IssueQuery.count_repo_issues(user.repos, status: :open)
      }
      render(conn, "index.html", user: user, stats: Map.new(user.repos, &{&1.id, stats(&1, batch_stats)}))
    end || {:error, :not_found}
  end

  @doc """
  Renders a repository creation form.
  """
  @spec new(Plug.Conn.t, map) :: Plug.Conn.t
  def new(conn, %{} = _params) do
    if verified?(conn),
      do: render(conn, "new.html", changeset: Repo.changeset(%Repo{})),
    else: {:error, :forbidden}
  end

  @doc """
  Creates a new repository.
  """
  @spec create(Plug.Conn.t, map) :: Plug.Conn.t
  def create(conn, %{"repo" => repo_params} = _params) do
    user = current_user(conn)
    if verified?(user) do
      case Repo.create(user, repo_params) do
        {:ok, repo} ->
          conn
          |> put_flash(:info, "Repository '#{repo.owner_login}/#{repo.name}' created.")
          |> redirect(to: Routes.codebase_path(conn, :show, user, repo))
        {:error, changeset} ->
          conn
          |> put_flash(:error, "Something went wrong! Please check error(s) below.")
          |> put_status(:bad_request)
          |> render("new.html", changeset: %{changeset|action: :insert})
      end
    end || {:error, :forbidden}
  end

  @doc """
  Renders a repository edit form.
  """
  @spec edit(Plug.Conn.t, map) :: Plug.Conn.t
  def edit(conn, %{"user_login" => user_login, "repo_name" => repo_name} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      if authorized?(conn, repo, :admin),
        do: render(conn, "edit.html", repo: repo, repo_open_issue_count: IssueQuery.count_repo_issues(repo, status: :open), changeset: Repo.changeset(repo)),
      else: {:error, :forbidden}
    end || {:error, :not_found}
  end

  @doc """
  Updates a repository.
  """
  @spec update(Plug.Conn.t, map) :: Plug.Conn.t
  def update(conn, %{"user_login" => user_login, "repo_name" => repo_name, "repo" => repo_params} = _params) do
    user = current_user(conn)
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: user) do
      if authorized?(user, repo, :admin) do
        case Repo.update(repo, repo_params) do
          {:ok, repo} ->
            conn
            |> put_flash(:info, "Repository '#{repo.owner_login}/#{repo.name}' updated.")
            |> redirect(to: Routes.repo_path(conn, :edit, repo.owner_login, repo))
          {:error, changeset} ->
            conn
            |> put_flash(:error, "Something went wrong! Please check error(s) below.")
            |> put_status(:bad_request)
            |> render("edit.html", repo: repo, repo_open_issue_count: IssueQuery.count_repo_issues(repo, status: :open), changeset: %{changeset|action: :insert})
        end
      end || {:error, :forbidden}
    end || {:error, :not_found}
  end

  @doc """
  Updates a repository.
  """
  @spec delete(Plug.Conn.t, map) :: Plug.Conn.t
  def delete(conn, %{"user_login" => user_login, "repo_name" => repo_name} = _params) do
    user = current_user(conn)
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: user) do
      if repo.owner_id == user.id do
        repo = Repo.delete!(repo)
        conn
        |> put_flash(:info, "Repository '#{repo.owner_login}/#{repo.name}' deleted.")
        |> redirect(to: Routes.user_path(conn, :show, user))
      end || {:error, :forbidden}
    end || {:error, :not_found}
  end

  #
  # Helpers
  #

  defp stats(repo, batch) do
    with {:ok, agent} <- GitAgent.unwrap(repo),
         {:ok, refs} = GitAgent.references(agent) do
      group_refs = Enum.group_by(refs, &(&1.type))
      %{
        branches: length(group_refs[:branch] || []),
        tags: length(group_refs[:tag] || []),
        issues: batch.issues[repo.id] || 0,
        contributors: batch.contributors[repo.id] || 0
      }
    else
      {:error, reason} ->
        Logger.warn(reason)
        %{
          branches: 0,
          tags: 0,
          issues: batch.issues[repo.id] || 0,
          contributors: batch.contributors[repo.id] || 0
        }
    end
  end
end
