defmodule GitGud.Web.RepositoryController do
  @moduledoc """
  Module responsible for handling CRUD repository requests.
  """

  use GitGud.Web, :controller

  alias GitRekt.Git

  alias GitGud.User
  alias GitGud.UserQuery

  alias GitGud.Repo
  alias GitGud.RepoQuery

  alias GitGud.Web.GitView

  plug :ensure_authenticated when action in [:create, :update, :delete]

  action_fallback GitGud.Web.FallbackController

  @doc """
  Returns all repository for a given user.
  """
  @spec index(Plug.Conn.t, map) :: Plug.Conn.t
  def index(conn, %{"user" => username} = _params) do
    repos = RepoQuery.user_repositories(username)
    render(conn, "repository_list.json", repositories: repos)
  end

  @doc """
  Returns a single repository.
  """
  @spec show(Plug.Conn.t, map) :: Plug.Conn.t
  def show(conn, %{"user" => username, "repo" => path} = _params) do
    case fetch_repo({username, path}, conn.assigns[:user], :read) do
      {:ok, repo} -> render(conn, "repository.json", repository: repo)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Creates a new repository.
  """
  @spec create(Plug.Conn.t, map) :: Plug.Conn.t
  def create(conn, %{"repository" => repo_params} = _params) do
    repo_params = Map.put(repo_params, "owner_id", conn.assigns.user.id)
    case Repo.create(repo_params) do
      {:ok, repo, _pid} ->
        repo = struct(repo, owner: conn.assigns.user)
        conn
        |> put_status(:created)
        |> put_resp_header("location", repository_path(conn, :show, repo.owner.username, repo.path))
        |> render("repository.json", repository: repo)
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Updates an existing repository.
  """
  @spec update(Plug.Conn.t, map) :: Plug.Conn.t
  def update(conn, %{"user" => username, "repo" => path, "repository" => repo_params}) do
    repo_params = Map.delete(repo_params, "owner_id")
    with {:ok, repo} <- fetch_repo({username, path}, conn.assigns[:user], :write),
         {:ok, repo} <- Repo.update(repo, repo_params), do:
      render(conn, "repository.json", repository: repo)
  end

  @doc """
  Deletes an existing repository.
  """
  @spec delete(Plug.Conn.t, map) :: Plug.Conn.t
  def delete(conn, %{"user" => username, "repo" => path} = _params) do
    with {:ok, repo} <- fetch_repo({username, path}, conn.assigns[:user], :write),
         {:ok, _del} <- Repo.delete(repo), do:
      send_resp(conn, :no_content, "")
  end

  @doc """
  Returns all available branches for a repository.
  """
  @spec branch_list(Plug.t, map) :: Plug.t
  def branch_list(conn, %{"user" => username, "repo" => path} = _params) do
    with {:ok, repo} <- fetch_repo({username, path} , conn.assigns[:user], :read),
         {:ok, handle, refs} <- fetch_branches(repo), do:
      render(conn, GitView, "branch_list.json", references: refs, repository: repo, handle: handle)
  end

  @doc """
  Returns a single branch for a repository.
  """
  @spec branch(Plug.t, map) :: Plug.t
  def branch(conn, %{"user" => username, "repo" => path, "branch" => shorthand} = _params) do
    with {:ok, repo} <- fetch_repo({username, path} , conn.assigns[:user], :read),
         {:ok, handle, name, oid, commit} <- fetch_branch(repo, shorthand), do:
      render(conn, GitView, "branch.json", reference: {oid, name, shorthand, commit}, repository: repo, handle: handle)
  end

  @doc """
  Returns all tags for a repository.
  """
  @spec tag_list(Plug.t, map) :: Plug.t
  def tag_list(conn, %{"user" => username, "repo" => path} = _params) do
    with {:ok, repo} <- fetch_repo({username, path} , conn.assigns[:user], :read),
         {:ok, handle, refs} <- fetch_tags(repo), do:
      render(conn, GitView, "tag_list.json", references: refs, repository: repo, handle: handle)
  end

  @doc """
  Returns a single tag for a repository.
  """
  @spec tag(Plug.t, map) :: Plug.t
  def tag(conn, %{"user" => username, "repo" => path, "tag" => shorthand} = _params) do
    with {:ok, repo} <- fetch_repo({username, path} , conn.assigns[:user], :read),
         {:ok, handle, tag} <- fetch_tag(repo, shorthand), do:
      render(conn, GitView, "tag.json", tag: tag, handle: handle)
  end

  @doc """
  Returns a single commit for a repository.
  """
  @spec commit(Plug.t, map) :: Plug.t
  def commit(conn, %{"user" => username, "repo" => path, "spec" => spec} = _params) do
    with {:ok, repo} <- fetch_repo({username, path} , conn.assigns[:user], :read),
         {:ok, handle, oid, commit} <- fetch_commit(repo, spec), do:
      render(conn, GitView, "commit.json", commit: {oid, commit}, repository: repo, handle: handle)
  end

  @doc """
  Returns all commits for a repository revision.
  """
  @spec revwalk(Plug.t, map) :: Plug.t
  def revwalk(conn, %{"user" => username, "repo" => path, "spec" => spec} = _params) do
    with {:ok, repo} <- fetch_repo({username, path} , conn.assigns[:user], :read),
         {:ok, handle, commits} <- fetch_revwalk(repo, spec), do:
      render(conn, GitView, "revwalk.json", commits: commits, repository: repo, handle: handle)
  end

  @doc """
  Browses a repository's tree by path.
  """
  @spec browse_tree(Plug.t, map) :: Plug.t
  def browse_tree(conn, %{"user" => username, "repo" => path, "spec" => spec, "path" => []} = _params) do
    with {:ok, repo} <- fetch_repo({username, path} , conn.assigns[:user], :read),
         {:ok, tree} <- fetch_tree(repo, spec), do:
      render(conn, GitView, "tree.json", spec: spec, path: "/", tree: tree, repository: repo)
  end

  @spec browse_tree(Plug.t, map) :: Plug.t
  def browse_tree(conn, %{"user" => username, "repo" => path, "spec" => spec, "path" => paths} = _params) do
    tree_path = Path.join(paths)
    with {:ok, repo} <- fetch_repo({username, path} , conn.assigns[:user], :read),
         {:ok, tree} <- fetch_tree(repo, spec, tree_path), do:
      render(conn, GitView, "tree.json", spec: spec, path: tree_path, tree: tree, repository: repo)
  end

  @spec download_blob(Plug.t, map) :: Plug.t
  def download_blob(_conn, %{"path" => []} = _params) do
    {:error, :invalid_path}
  end

  @spec download_blob(Plug.t, map) :: Plug.t
  def download_blob(conn, %{"user" => username, "repo" => path, "spec" => spec, "path" => paths} = _params) do
    blob_path = Path.join(paths)
    with {:ok, repo} <- fetch_repo({username, path} , conn.assigns[:user], :read),
         {:ok, blob} <- fetch_blob(repo, spec, blob_path), do:
      conn
      |> put_resp_header("content-type", MIME.from_path(blob_path))
      |> send_resp(200, blob)
  end

  #
  # Helpers
  #

  defp has_access?(user, repo, :read), do: Repo.can_read?(repo, user)
  defp has_access?(user, repo, :write), do: Repo.can_write?(repo, user)

  defp fetch_repo({username, path}, %User{username: username}, _auth_mode) do
    if repository = RepoQuery.user_repository(username, path),
      do: {:ok, repository},
    else: {:error, :not_found}
  end

  defp fetch_repo({username, path}, auth_user, auth_mode) do
    with user when not is_nil(user) <- UserQuery.by_username(username),
         repo when not is_nil(repo) <- RepoQuery.user_repository(user, path),
         true <- has_access?(auth_user, repo, auth_mode) do
      {:ok, repo}
    else
      nil   -> {:error, :not_found}
      false -> {:error, :unauthorized}
    end
  end

  defp fetch_branches(repo) do
    with {:ok, handle} <- Git.repository_open(Repo.workdir(repo)),
         {:ok, stream} <- Git.reference_stream(handle, "refs/heads/*"), do:
      {:ok, handle, Enum.map(stream, &resolve_commit(handle, &1))}
  end

  defp fetch_branch(repo, shorthand) do
    with {:ok, handle} <- Git.repository_open(Repo.workdir(repo)),
         {:ok, "refs/heads/" <> ^shorthand = refname, :oid, oid} <- Git.reference_dwim(handle, shorthand),
         {:ok, :commit, commit} <- Git.object_lookup(handle, oid), do:
      {:ok, handle, refname, oid, commit}
  end

  defp fetch_tags(repo) do
    with {:ok, handle} <- Git.repository_open(Repo.workdir(repo)),
         {:ok, stream} <- Git.reference_stream(handle, "refs/tags/*"), do:
      {:ok, handle, Enum.map(stream, &resolve_tag(handle, &1))}
  end

  defp fetch_tag(repo, shorthand) do
    with {:ok, handle} <- Git.repository_open(Repo.workdir(repo)),
         {:ok, "refs/tags/" <> ^shorthand = refname, type, target} <- Git.reference_dwim(handle, shorthand), do:
      {:ok, handle, resolve_tag(handle, {refname, shorthand, type, target})}
  end

  defp fetch_commit(repo, spec) do
    with {:ok, handle} <- Git.repository_open(Repo.workdir(repo)),
         {:ok, commit, :commit, oid} <- Git.revparse_single(handle, spec), do:
      {:ok, handle, oid, commit}
  end

  defp fetch_revwalk(repo, spec) do
    with {:ok, handle, oid, _commit} <- fetch_commit(repo, spec),
         {:ok, walk} <- Git.revwalk_new(handle),
          :ok <- Git.revwalk_push(walk, oid),
         {:ok, stream} <- Git.revwalk_stream(walk), do:
      {:ok, handle, Enum.map(stream, &resolve_commit(handle, &1))}
  end

  defp fetch_tree(repo, spec) do
    with {:ok, _handle, _oid, commit} <- fetch_commit(repo, spec),
         {:ok, _oid, tree} <- Git.commit_tree(commit),
         {:ok, list} <- Git.tree_list(tree), do:
      {:ok, list}
  end

  defp fetch_tree(repo, spec, tree_path) do
    with {:ok, handle, _oid, commit} <- fetch_commit(repo, spec),
         {:ok, _oid, tree} <- Git.commit_tree(commit),
         {:ok, _mode, :tree, oid, _path} <- Git.tree_bypath(tree, tree_path),
         {:ok, :tree, tree} <- Git.object_lookup(handle, oid),
         {:ok, list} <- Git.tree_list(tree), do:
      {:ok, list}
  end

  defp fetch_blob(repo, spec, blob_path) do
    with {:ok, handle, _oid, commit} <- fetch_commit(repo, spec),
         {:ok, _oid, tree} <- Git.commit_tree(commit),
         {:ok, _mode, :blob, oid, _path} <- Git.tree_bypath(tree, blob_path),
         {:ok, :blob, blob} <- Git.object_lookup(handle, oid),
         {:ok, data} <- Git.blob_content(blob), do:
      {:ok, data}
  end

  defp resolve_commit(handle, {refname, shorthand, :oid, oid}) do
    {:ok, :commit, commit} = Git.object_lookup(handle, oid)
    {oid, refname, shorthand, commit}
  end

  defp resolve_commit(handle, oid) do
    {:ok, :commit, commit} = Git.object_lookup(handle, oid)
    {oid, commit}
  end

  defp resolve_tag(handle, {_refname, shorthand, :oid, oid}) do
    case Git.object_lookup(handle, oid) do
      {:ok, :tag, tag} -> {oid, tag}
      {:ok, :commit, commit} -> {oid, commit, shorthand}
    end
  end
end
