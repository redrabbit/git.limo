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
  Returns all available branches for a repository.
  """
  @spec branch_list(Plug.t, map) :: Plug.t
  def branch_list(conn, %{"user" => username, "repo" => path} = _params) do
    with {:ok, repo} <- fetch_repo({username, path} , conn.assigns[:user], :read),
         {:ok, handle, refs} <- fetch_branches(repo), do:
      render(conn, GitView, "branch_list.json", references: refs, handle: handle)
  end

  @doc """
  Returns a single branch for a repository.
  """
  @spec branch(Plug.t, map) :: Plug.t
  def branch(conn, %{"user" => username, "repo" => path, "dwim" => shorthand} = _params) do
    with {:ok, repo} <- fetch_repo({username, path} , conn.assigns[:user], :read),
         {:ok, handle, name, oid, commit} <- fetch_branch(repo, shorthand), do:
      render(conn, GitView, "branch.json", reference: {oid, name, shorthand, commit}, handle: handle)
  end

  @doc """
  Returns all tags for the given repository.
  """
  @spec tag_list(Plug.t, map) :: Plug.t
  def tag_list(conn, %{"user" => username, "repo" => path} = _params) do
    with {:ok, repo} <- fetch_repo({username, path} , conn.assigns[:user], :read),
         {:ok, handle, refs} <- fetch_tags(repo), do:
      render(conn, GitView, "tag_list.json", references: refs, handle: handle)
  end

  @doc """
  Returns a single tag for a repository.
  """
  @spec tag(Plug.t, map) :: Plug.t
  def tag(conn, %{"user" => username, "repo" => path, "spec" => spec} = _params) do
    with {:ok, repo} <- fetch_repo({username, path} , conn.assigns[:user], :read),
         {:ok, handle, oid, tag} <- fetch_tag(repo, spec), do:
      render(conn, GitView, "tag.json", tag: {oid, tag}, handle: handle)
  end

  @doc """
  Returns all commits for a repository revision.
  """
  @spec revwalk(Plug.t, map) :: Plug.t
  def revwalk(conn, %{"user" => username, "repo" => path, "spec" => spec} = _params) do
    with {:ok, repo} <- fetch_repo({username, path} , conn.assigns[:user], :read),
         {:ok, handle, commits} <- fetch_revwalk(repo, spec), do:
      render(conn, GitView, "revwalk.json", commits: commits, handle: handle)
  end

  @doc """
  Browses a repository's tree by path.
  """
  def browse_tree(conn, %{"user" => username, "repo" => path, "spec" => spec, "path" => []} = _params) do
    with {:ok, repo} <- fetch_repo({username, path} , conn.assigns[:user], :read),
         {:ok, handle, oid, tree} <- fetch_tree(repo, spec), do:
      render(conn, GitView, "tree.json", tree: {0, oid, tree, "/"}, handle: handle) # TODO
  end

  def browse_tree(conn, %{"user" => username, "repo" => path, "spec" => spec, "path" => paths} = _params) do
    tree_path = Path.join(paths)
    with {:ok, repo} <- fetch_repo({username, path} , conn.assigns[:user], :read),
         {:ok, handle, mode, type, oid, obj, _path} <- fetch_tree(repo, spec, tree_path), do:
      render(conn, GitView, "tree.json", [{type, {mode, oid, obj, tree_path}}, handle: handle])
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
        |> render("show.json", repository: repo)
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
      render(conn, "show.json", repository: repo)
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

  #
  # Helpers
  #

  defp has_access?(user, repo, :read), do: Repo.can_read?(user, repo)
  defp has_access?(user, repo, :write), do: Repo.can_write?(user, repo)

  defp fetch_repo({username, path}, %User{username: username}, _auth_mode) do
    if repository = RepoQuery.user_repository(username, path),
      do: {:ok, repository},
    else: {:error, :not_found}
  end

  defp fetch_repo({username, path}, auth_user, auth_mode) do
    with user when not is_nil(user) <- UserQuery.get(username),
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
         {:ok, name, :oid, oid} <- Git.reference_dwim(handle, shorthand),
         {:ok, :commit, commit} <- Git.object_lookup(handle, oid), do:
      {:ok, handle, name, oid, commit}
  end

  defp fetch_tags(repo) do
    with {:ok, handle} <- Git.repository_open(Repo.workdir(repo)),
         {:ok, stream} <- Git.reference_stream(handle, "refs/tags/*"), do:
      {:ok, handle, Enum.map(stream, &resolve_tag(handle, &1))}
  end

  defp fetch_tag(repo, spec) do
    with {:ok, handle} <- Git.repository_open(Repo.workdir(repo)),
         {:ok, tag, :tag, oid} <- Git.revparse_single(handle, spec), do:
      {:ok, handle, oid, tag}
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
    with {:ok, handle, _oid, commit} <- fetch_commit(repo, spec),
         {:ok, oid, tree} <- Git.commit_tree(commit), do:
      {:ok, handle, oid, tree}
  end

  defp fetch_tree(repo, spec, tree_path) do
    with {:ok, handle, _oid, tree} <- fetch_tree(repo, spec),
         {:ok, mode, type, oid, path} <- Git.tree_bypath(tree, tree_path),
         {:ok, ^type, obj} <- Git.object_lookup(handle, oid), do:
      {:ok, handle, mode, type, oid, obj, path}
  end

  defp resolve_commit(handle, {refname, shorthand, :oid, oid}) do
    {:ok, :commit, commit} = Git.object_lookup(handle, oid)
    {oid, refname, shorthand, commit}
  end

  defp resolve_commit(handle, oid) do
    {:ok, :commit, commit} = Git.object_lookup(handle, oid)
    {oid, commit}
  end

  defp resolve_tag(handle, {_refname, _shorthand, :oid, oid}) do
    {:ok, :tag, tag} = Git.object_lookup(handle, oid)
    {oid, tag}
  end
end
