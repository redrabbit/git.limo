defmodule GitGud.Web.CodebaseController do
  @moduledoc """
  Module responsible for CRUD actions on `GitGud.Repo`.
  """

  use GitGud.Web, :controller

  alias GitGud.RepoQuery

  alias GitRekt.GitAgent
  alias GitRekt.{GitBlob, GitTree}

  import GitRekt.Git, only: [oid_parse: 1]

  plug :put_layout, :repo

  action_fallback GitGud.Web.FallbackController

  @doc """
  Renders a repository codebase overview.
  """
  @spec show(Plug.Conn.t, map) :: Plug.Conn.t
  def show(conn, %{"user_login" => user_login, "repo_name" => repo_name} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      case GitAgent.empty?(repo) do
        {:ok, true} ->
          render(conn, "initialize.html", repo: repo)
        {:ok, false} ->
          with {:ok, head} <- GitAgent.head(repo),
               {:ok, commit} <- GitAgent.peel(repo, head, :commit),
               {:ok, tree} <- GitAgent.tree(repo, commit), do:
            render(conn, "show.html", repo: repo, revision: head, commit: commit, tree: tree, tree_path: [], stats: stats(repo, head))
        {:error, reason} ->
          {:error, reason}
      end
    end || {:error, :not_found}
  end

  @doc """
  Renders all branches of a repository.
  """
  @spec branches(Plug.Conn.t, map) :: Plug.Conn.t
  def branches(conn, %{"user_login" => user_login, "repo_name" => repo_name} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      with {:ok, head} <- GitAgent.head(repo),
           {:ok, branches} <- GitAgent.branches(repo), do:
        render(conn, "branch_list.html", repo: repo, head: head, branches: Enum.to_list(branches))
    end || {:error, :not_found}
  end

  @doc """
  Renders all tags of a repository.
  """
  @spec tags(Plug.Conn.t, map) :: Plug.Conn.t
  def tags(conn, %{"user_login" => user_login, "repo_name" => repo_name} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      case GitAgent.tags(repo) do
        {:ok, tags} ->
          render(conn, "tag_list.html", repo: repo, tags: Enum.to_list(tags))
        {:error, reason} ->
          {:error, reason}
      end
    end || {:error, :not_found}
  end

  @doc """
  Renders a single commit.
  """
  @spec commit(Plug.Conn.t, map) :: Plug.Conn.t
  def commit(conn, %{"user_login" => user_login, "repo_name" => repo_name, "oid" => oid} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      with {:ok, object} <- GitAgent.object(repo, oid_parse(oid)),
           {:ok, commit} <- GitAgent.peel(repo, object, :commit),
           {:ok, parents} <- GitAgent.commit_parents(repo, commit),
           {:ok, diff} <- GitAgent.diff(repo, Enum.at(parents, 0), commit), do:
        render(conn, "commit.html", repo: repo, commit: commit, commit_parents: Enum.to_list(parents), diff: diff)
    end || {:error, :not_found}
  end

  @doc """
  Renders all commits for a specific revision.
  """
  @spec history(Plug.Conn.t, map) :: Plug.Conn.t
  def history(conn, %{"user_login" => user_login, "repo_name" => repo_name, "revision" => revision, "path" => []} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      with {:ok, object, reference} <- GitAgent.revision(repo, revision),
           {:ok, history} <- GitAgent.history(repo, object), do:
        render(conn, "commit_list.html", repo: repo, revision: reference || object, commits: history, tree_path: [])
    end || {:error, :not_found}
  end

  def history(conn, %{"user_login" => user_login, "repo_name" => repo_name, "revision" => revision, "path" => tree_path} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      with {:ok, object, reference} <- GitAgent.revision(repo, revision),
           {:ok, history} <- GitAgent.history(repo, object, pathspec: Path.join(tree_path)), do:
        render(conn, "commit_list.html", repo: repo, revision: reference || object, commits: history, tree_path: tree_path)
    end || {:error, :not_found}
  end

  def history(conn, %{"user_login" => user_login, "repo_name" => repo_name} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      case GitAgent.head(repo) do
        {:ok, reference} ->
          redirect(conn, to: Routes.codebase_path(conn, :history, user_login, repo_name, reference, []))
        {:error, reason} ->
          {:error, reason}
      end
    end || {:error, :not_found}
  end

  @doc """
  Renders a tree for a specific revision and path.
  """
  @spec tree(Plug.Conn.t, map) :: Plug.Conn.t
  def tree(conn, %{"user_login" => user_login, "repo_name" => repo_name, "revision" => revision, "path" => []} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      with {:ok, object, reference} <- GitAgent.revision(repo, revision),
           {:ok, commit} <- GitAgent.peel(repo, object, :commit),
           {:ok, tree} <- GitAgent.tree(repo, object), do:
        render(conn, "show.html", repo: repo, revision: reference || object, commit: commit, tree: tree, tree_path: [], stats: stats(repo, reference || object))
    end || {:error, :not_found}
  end

  def tree(conn, %{"user_login" => user_login, "repo_name" => repo_name, "revision" => revision, "path" => tree_path} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      with {:ok, object, reference} <- GitAgent.revision(repo, revision),
           {:ok, commit} <- GitAgent.peel(repo, object, :commit),
           {:ok, tree_entry} <- GitAgent.tree_entry_by_path(repo, object, Path.join(tree_path)),
           {:ok, tree_entry_target} <- GitAgent.tree_entry_target(repo, tree_entry) do
        case tree_entry_target do
          %GitBlob{} ->
            unless reference  do
              conn
              |> put_status(:moved_permanently)
              |> redirect(to: Routes.codebase_path(conn, :blob, repo.owner, repo, revision, tree_path))
            else
              redirect(conn, to: Routes.codebase_path(conn, :blob, repo.owner, repo, revision, tree_path))
            end
          %GitTree{} = tree ->
            render(conn, "tree.html", repo: repo, revision: reference || object, commit: commit, tree: tree, tree_path: tree_path)
        end
      end
    end || {:error, :not_found}
  end

  @doc """
  Renders a blob for a specific revision and path.
  """
  @spec blob(Plug.Conn.t, map) :: Plug.Conn.t
  def blob(conn, %{"user_login" => user_login, "repo_name" => repo_name, "revision" => revision, "path" => blob_path} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      with {:ok, object, reference} <- GitAgent.revision(repo, revision),
           {:ok, commit} <- GitAgent.peel(repo, object, :commit),
           {:ok, tree_entry} <- GitAgent.tree_entry_by_path(repo, object, Path.join(blob_path)),
           {:ok, tree_entry_target} <- GitAgent.tree_entry_target(repo, tree_entry) do
        case tree_entry_target do
          %GitTree{} ->
            unless reference  do
              conn
              |> put_status(:moved_permanently)
              |> redirect(to: Routes.codebase_path(conn, :tree, repo.owner, repo, revision, blob_path))
            else
              redirect(conn, to: Routes.codebase_path(conn, :blob, repo.owner, repo, revision, blob_path))
            end
          %GitBlob{} = blob ->
            render(conn, "blob.html", repo: repo, revision: reference || object, commit: commit, blob: blob, tree_path: blob_path)
        end
      end
    end || {:error, :not_found}
  end

  #
  # Helpers
  #

  defp stats(repo, revision) do
    with {:ok, branches} <- GitAgent.branches(repo),
         {:ok, tags} <- GitAgent.tags(repo),
         {:ok, commit} <- GitAgent.peel(repo, revision, :commit),
         {:ok, history} <- GitAgent.history(repo, commit) do
      %{branches: Enum.count(branches), tags: Enum.count(tags), commits: Enum.count(history)}
    else
      {:error, _reason} ->
        %{commits: 0, branches: 0, tags: 0}
    end
  end
end
