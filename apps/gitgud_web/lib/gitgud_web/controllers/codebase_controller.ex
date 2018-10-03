defmodule GitGud.Web.CodebaseController do
  @moduledoc """
  Module responsible for CRUD actions on `GitGud.Repo`.
  """

  use GitGud.Web, :controller

  alias GitGud.Repo
  alias GitGud.RepoQuery

  alias GitGud.GitCommit
  alias GitGud.GitReference
  alias GitGud.GitTree
  alias GitGud.GitTreeEntry


  plug :put_layout, :repository

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
                 {:ok, commit} <- GitReference.target(head),
                 {:ok, tree} <- GitCommit.tree(commit), do:
              render(conn, "show.html", repo: repo, reference: head, tree: tree, tree_path: [], stats: stats!(head))
    else
      {:error, :not_found}
    end
  end

  @doc """
  Renders all branches of a repository.
  """
  @spec branches(Plug.Conn.t, map) :: Plug.Conn.t
  def branches(conn, %{"username" => username, "repo_name" => repo_name} = _params) do
    if repo = RepoQuery.user_repo(username, repo_name, viewer: current_user(conn)) do
      with {:ok, branches} <- Repo.git_branches(repo), do:
        render(conn, "branch_list.html", repo: repo, branches: branches)
    else
      {:error, :not_found}
    end
  end

  @doc """
  Renders all tags of a repository.
  """
  @spec tags(Plug.Conn.t, map) :: Plug.Conn.t
  def tags(conn, %{"username" => username, "repo_name" => repo_name} = _params) do
    if repo = RepoQuery.user_repo(username, repo_name, viewer: current_user(conn)) do
      with {:ok, tags} <- Repo.git_tags(repo), do:
        render(conn, "tag_list.html", repo: repo, tags: tags)
    else
      {:error, :not_found}
    end
  end

  @doc """
  Renders all commits for a specific revision.
  """
  @spec commits(Plug.Conn.t, map) :: Plug.Conn.t
  def commits(conn, %{"username" => username, "repo_name" => repo_name, "spec" => repo_spec} = _params) do
    if repo = RepoQuery.user_repo(username, repo_name, viewer: current_user(conn)) do
      with {:ok, reference} <- Repo.git_reference(repo, repo_spec),
           {:ok, history} <- GitReference.history(reference), do:
        render(conn, "commit_list.html", repo: repo, reference: reference, commits: history)
    else
      {:error, :not_found}
    end
  end

  def commits(conn, %{"username" => username, "repo_name" => repo_name} = _params) do
    if repo = RepoQuery.user_repo(username, repo_name, viewer: current_user(conn)) do
      with {:ok, head} <- Repo.git_head(repo), do:
        redirect(conn, to: codebase_path(conn, :commits, username, repo, head))
    else
      {:error, :not_found}
    end
  end

  @doc """
  Renders a single commit.
  """
  @spec commit(Plug.Conn.t, map) :: Plug.Conn.t
  def commit(conn, %{"username" => username, "repo_name" => repo_name, "oid" => oid} = _params) do
    if repo = RepoQuery.user_repo(username, repo_name, viewer: current_user(conn)) do
      with {:ok, commit} <- Repo.git_revision(repo, oid), do:
        render(conn, "commit.html", repo: repo, commit: commit)
    else
      {:error, :not_found}
    end
  end

  @doc """
  Renders a tree for a specific revision and path.
  """
  @spec tree(Plug.Conn.t, map) :: Plug.Conn.t
  def tree(conn, %{"username" => username, "repo_name" => repo_name, "spec" => repo_spec, "path" => []} = _params) do
    if repo = RepoQuery.user_repo(username, repo_name, viewer: current_user(conn)) do
      with {:ok, reference} <- Repo.git_reference(repo, repo_spec),
           {:ok, commit} <- GitReference.target(reference),
           {:ok, tree} <- GitCommit.tree(commit), do:
        render(conn, "show.html", repo: repo, reference: reference, tree: tree, tree_path: [], stats: stats!(reference))
    else
      {:error, :not_found}
    end
  end

  def tree(conn, %{"username" => username, "repo_name" => repo_name, "spec" => repo_spec, "path" => tree_path} = _params) do
    if repo = RepoQuery.user_repo(username, repo_name, viewer: current_user(conn)) do
      with {:ok, reference} <- Repo.git_reference(repo, repo_spec),
           {:ok, commit} <- GitReference.target(reference),
           {:ok, tree} <- GitCommit.tree(commit),
           {:ok, tree_entry} <- GitTree.by_path(tree, Path.join(tree_path)),
           {:ok, tree} <- GitTreeEntry.object(tree_entry), do:
        render(conn, "tree.html", repo: repo, reference: reference, tree: tree, tree_path: tree_path)
    else
      {:error, :not_found}
    end
  end

  @doc """
  Renders a blob for a specific revision and path.
  """
  @spec blob(Plug.Conn.t, map) :: Plug.Conn.t
  def blob(conn, %{"username" => username, "repo_name" => repo_name, "spec" => repo_spec, "path" => blob_path} = _params) do
    if repo = RepoQuery.user_repo(username, repo_name, viewer: current_user(conn)) do
      with {:ok, reference} <- Repo.git_reference(repo, repo_spec),
           {:ok, commit} <- GitReference.target(reference),
           {:ok, tree} <- GitCommit.tree(commit),
           {:ok, tree_entry} <- GitTree.by_path(tree, Path.join(blob_path)),
           {:ok, blob} <- GitTreeEntry.object(tree_entry), do:
        render(conn, "blob.html", repo: repo, reference: reference, blob: blob, tree_path: blob_path)
    else
      {:error, :not_found}
    end
  end

  #
  # Helpers
  #

  defp stats!(%GitReference{repo: repo} = reference) do
    with {:ok, history} <- GitReference.history(reference),
         {:ok, branches} <- Repo.git_branches(repo),
         {:ok, tags} <- Repo.git_tags(repo), do:
      %{commits: Enum.count(history.enum), branches: Enum.count(branches.enum), tags: Enum.count(tags.enum), maintainers: Repo.maintainer_count(repo)}
  end
end
