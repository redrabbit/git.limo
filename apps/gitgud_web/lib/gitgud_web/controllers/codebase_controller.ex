defmodule GitGud.Web.CodebaseController do
  @moduledoc """
  Module responsible for CRUD actions on `GitGud.Repo`.
  """

  use GitGud.Web, :controller

  alias GitGud.Repo
  alias GitGud.RepoQuery
  alias GitGud.GitTree
  alias GitGud.GitTreeEntry

  plug :put_layout, :repo

  action_fallback GitGud.Web.FallbackController

  @doc """
  Renders a repository codebase overview.
  """
  @spec show(Plug.Conn.t, map) :: Plug.Conn.t
  def show(conn, %{"username" => username, "repo_name" => repo_name} = _params) do
    if repo = RepoQuery.user_repo(username, repo_name, viewer: current_user(conn)) do
      if Repo.empty?(repo),
        do: render(conn, "initialize.html", repo: repo),
      else: with {:ok, head} <- Repo.git_head(repo),
                 {:ok, tree} <- Repo.git_tree(head), do:
              render(conn, "show.html", repo: repo, revision: head, tree: tree, tree_path: [], stats: stats!(head))
    end || {:error, :not_found}
  end

  @doc """
  Renders all branches of a repository.
  """
  @spec branches(Plug.Conn.t, map) :: Plug.Conn.t
  def branches(conn, %{"username" => username, "repo_name" => repo_name} = _params) do
    if repo = RepoQuery.user_repo(username, repo_name, viewer: current_user(conn)) do
      with {:ok, head} <- Repo.git_head(repo),
           {:ok, branches} <- Repo.git_branches(repo), do:
        render(conn, "branch_list.html", repo: repo, head: head, branches: branches)
    end || {:error, :not_found}
  end

  @doc """
  Renders all tags of a repository.
  """
  @spec tags(Plug.Conn.t, map) :: Plug.Conn.t
  def tags(conn, %{"username" => username, "repo_name" => repo_name} = _params) do
    if repo = RepoQuery.user_repo(username, repo_name, viewer: current_user(conn)) do
      with {:ok, tags} <- Repo.git_tags(repo), do:
        render(conn, "tag_list.html", repo: repo, tags: tags)
    end || {:error, :not_found}
  end

  @doc """
  Renders a single commit.
  """
  @spec commit(Plug.Conn.t, map) :: Plug.Conn.t
  def commit(conn, %{"username" => username, "repo_name" => repo_name, "oid" => oid} = _params) do
    if repo = RepoQuery.user_repo(username, repo_name, viewer: current_user(conn)) do
      with {:ok, commit} <- Repo.git_object(repo, oid), do:
        render(conn, "commit.html", repo: repo, commit: commit)
    end || {:error, :not_found}
  end

  @doc """
  Renders all commits for a specific revision.
  """
  @spec history(Plug.Conn.t, map) :: Plug.Conn.t
  def history(conn, %{"username" => username, "repo_name" => repo_name, "revision" => revision} = _params) do
    if repo = RepoQuery.user_repo(username, repo_name, viewer: current_user(conn)) do
      with {:ok, object, reference} <- Repo.git_revision(repo, revision),
           {:ok, history} <- Repo.git_history(object), do:
        render(conn, "commit_list.html", repo: repo, revision: reference || object, commits: history)
    end || {:error, :not_found}
  end

  def history(conn, %{"username" => username, "repo_name" => repo_name} = _params) do
    if repo = RepoQuery.user_repo(username, repo_name, viewer: current_user(conn)) do
      with {:ok, reference} <- Repo.git_head(repo),
           {:ok, history} <- Repo.git_history(reference), do:
        render(conn, "commit_list.html", repo: repo, revision: reference, commits: history)
    end || {:error, :not_found}
  end

  @doc """
  Renders a tree for a specific revision and path.
  """
  @spec tree(Plug.Conn.t, map) :: Plug.Conn.t
  def tree(conn, %{"username" => username, "repo_name" => repo_name, "revision" => revision, "path" => []} = _params) do
    if repo = RepoQuery.user_repo(username, repo_name, viewer: current_user(conn)) do
      with {:ok, object, reference} <- Repo.git_revision(repo, revision),
           {:ok, tree} <- Repo.git_tree(object), do:
        render(conn, "show.html", repo: repo, revision: reference || object, tree: tree, tree_path: [], stats: stats!(reference || object))
    end || {:error, :not_found}
  end

  def tree(conn, %{"username" => username, "repo_name" => repo_name, "revision" => revision, "path" => tree_path} = _params) do
    if repo = RepoQuery.user_repo(username, repo_name, viewer: current_user(conn)) do
      with {:ok, object, reference} <- Repo.git_revision(repo, revision),
           {:ok, tree} <- Repo.git_tree(object),
           {:ok, tree_entry} <- GitTree.by_path(tree, Path.join(tree_path)),
           {:ok, tree} <- GitTreeEntry.target(tree_entry), do:
        render(conn, "tree.html", repo: repo, revision: reference || object, tree: tree, tree_path: tree_path)
    end || {:error, :not_found}
  end

  @doc """
  Renders a blob for a specific revision and path.
  """
  @spec blob(Plug.Conn.t, map) :: Plug.Conn.t
  def blob(conn, %{"username" => username, "repo_name" => repo_name, "revision" => revision, "path" => blob_path} = _params) do
    if repo = RepoQuery.user_repo(username, repo_name, viewer: current_user(conn)) do
      with {:ok, object, reference} <- Repo.git_revision(repo, revision),
           {:ok, tree} <- Repo.git_tree(object),
           {:ok, tree_entry} <- GitTree.by_path(tree, Path.join(blob_path)),
           {:ok, blob} <- GitTreeEntry.target(tree_entry), do:
        render(conn, "blob.html", repo: repo, revision: reference || object, blob: blob, tree_path: blob_path)
    end || {:error, :not_found}
  end

  #
  # Helpers
  #

  defp stats!(%{repo: repo} = revision) do
    with {:ok, history} <- Repo.git_history(revision),
         {:ok, branches} <- Repo.git_branches(repo),
         {:ok, tags} <- Repo.git_tags(repo), do:
      %{commits: Enum.count(history.enum), branches: Enum.count(branches.enum), tags: Enum.count(tags.enum)}
  end
end
