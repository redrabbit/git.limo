defmodule GitGud.Web.RepositoryController do
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

  plug :ensure_authenticated when action in [:new, :create]
  plug :put_layout, :repository_layout when action not in [:new, :create]

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
        |> redirect(to: repository_path(conn, :show, user, repo))
      {:error, changeset} ->
        conn
        |> put_flash(:error, "Something went wrong! Please check error(s) below.")
        |> render("new.html", changeset: %{changeset|action: :insert})
    end
  end

  @doc """
  Renders a repository.
  """
  @spec show(Plug.Conn.t, map) :: Plug.Conn.t
  def show(conn, %{"username" => username, "repo_name" => repo_name} = _params) do
    if repo = RepoQuery.user_repository(username, repo_name) do
      if Repo.empty?(repo),
        do: render(conn, "initialize.html", repo: repo),
      else: with {:ok, head} <- Repo.git_head(repo),
                 {:ok, commit} <- GitReference.commit(head),
                 {:ok, tree} <- GitCommit.tree(commit), do:
              render(conn, "show.html", repo: repo, reference: head, tree: tree, tree_path: [], stats: stats(head))
    else
      {:error, :not_found}
    end
  end

  @doc """
  Renders all branches of a repository.
  """
  @spec branches(Plug.Conn.t, map) :: Plug.Conn.t
  def branches(conn, %{"username" => username, "repo_name" => repo_name} = _params) do
    if repo = RepoQuery.user_repository(username, repo_name) do
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
    if repo = RepoQuery.user_repository(username, repo_name) do
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
    if repo = RepoQuery.user_repository(username, repo_name) do
      with {:ok, reference} <- Repo.git_reference(repo, repo_spec),
           {:ok, commits} <- GitReference.commit_history(reference), do:
        render(conn, "commit_list.html", repo: repo, reference: reference, commits: commits)
    else
      {:error, :not_found}
    end
  end

  def commits(conn, %{"username" => username, "repo_name" => repo_name} = _params) do
    if repo = RepoQuery.user_repository(username, repo_name) do
      with {:ok, head} <- Repo.git_head(repo), do:
        redirect(conn, to: repository_path(conn, :commits, username, repo, head.shorthand))
    else
      {:error, :not_found}
    end
  end

  @doc """
  Renders a single commit.
  """
  @spec commit(Plug.Conn.t, map) :: Plug.Conn.t
  def commit(_conn, %{"username" => _username, "repo_name" => _repo_name, "oid" => _oid} = _params) do
    {:error, :not_found}
  end

  @doc """
  Renders a tree for a specific revision and path.
  """
  @spec tree(Plug.Conn.t, map) :: Plug.Conn.t
  def tree(conn, %{"username" => username, "repo_name" => repo_name, "spec" => repo_spec, "path" => []} = _params) do
    if repo = RepoQuery.user_repository(username, repo_name) do
      with {:ok, reference} <- Repo.git_reference(repo, repo_spec),
           {:ok, commit} <- GitReference.commit(reference),
           {:ok, tree} <- GitCommit.tree(commit), do:
        render(conn, "show.html", repo: repo, reference: reference, tree: tree, tree_path: [], stats: stats(reference))
    else
      {:error, :not_found}
    end
  end

  def tree(conn, %{"username" => username, "repo_name" => repo_name, "spec" => repo_spec, "path" => tree_path} = _params) do
    if repo = RepoQuery.user_repository(username, repo_name) do
      with {:ok, reference} <- Repo.git_reference(repo, repo_spec),
           {:ok, commit} <- GitReference.commit(reference),
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
    if repo = RepoQuery.user_repository(username, repo_name) do
      with {:ok, reference} <- Repo.git_reference(repo, repo_spec),
           {:ok, commit} <- GitReference.commit(reference),
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

  defp stats(_reference) do
    %{commits: 0, branches: 0, tags: 0, maintainers: 0}
  end
end
