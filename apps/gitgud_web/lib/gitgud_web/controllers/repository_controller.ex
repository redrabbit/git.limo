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

  plug :ensure_authenticated when action in [:create, :update, :delete]

  action_fallback GitGud.Web.FallbackController

  @doc """
  Returns all repository for a given user.
  """
  @spec index(Plug.Conn.t, map) :: Plug.Conn.t
  def index(conn, %{"user" => username} = _params) do
    repos = RepoQuery.user_repositories(username)
    render(conn, "index.json", repositories: repos)
  end

  @doc """
  Returns a single repository.
  """
  @spec show(Plug.Conn.t, map) :: Plug.Conn.t
  def show(conn, %{"user" => username, "repo" => path} = _params) do
    case fetch_repo({username, path}, conn.assigns[:user], :read) do
      {:ok, repo} -> render(conn, "show.json", repository: repo)
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

  @doc """
  Returns all available branch for a repository.
  """
  @spec branches(Plug.t, map) :: Plug.t
  def branches(conn, %{"user" => username, "repo" => path} = _params) do
    with {:ok, repo} <- fetch_repo({username, path} , conn.assigns[:user], :read),
         {:ok, handle} <- Git.repository_open(Repo.workdir(repo)), do:
      render(conn, "branches.json", refs: Git.reference_stream(handle, "refs/heads/*"))
  end

  @doc """
  Returns all parent commits for a repository revision.
  """
  @spec commits(Plug.t, map) :: Plug.t
  def commits(conn, %{"user" => username, "repo" => path} = params) do
    with {:ok, repo} <- fetch_repo({username, path} , conn.assigns[:user], :read),
         {:ok, handle} <- Git.repository_open(Repo.workdir(repo)),
         {:ok, _commit, :commit, oid} <- Git.revparse_single(handle, Map.get(params, "spec", "HEAD")),
         {:ok, walk} <- Git.revwalk_new(handle),
          :ok <- Git.revwalk_push(walk, oid), do:
      render(conn, "commits.json", revwalk: walk)
  end

  @doc """
  Browses a repository's tree by path.
  """
  def browse(conn, %{"user" => username, "repo" => path, "spec" => spec, "path" => []} = _params) do
    with {:ok, repo} <- fetch_repo({username, path} , conn.assigns[:user], :read),
         {:ok, handle} <- Git.repository_open(Repo.workdir(repo)),
         {:ok, commit, :commit, _oid} <- Git.revparse_single(handle, spec),
         {:ok, _oid, tree} <- Git.commit_tree(commit), do:
      render(conn, "browse.json", tree: tree)
  end

  def browse(conn, %{"user" => username, "repo" => path, "spec" => spec, "path" => paths} = _params) do
    with {:ok, repo} <- fetch_repo({username, path} , conn.assigns[:user], :read),
         {:ok, handle} <- Git.repository_open(Repo.workdir(repo)),
         {:ok, commit, :commit, _oid} <- Git.revparse_single(handle, spec),
         {:ok, _oid, tree} <- Git.commit_tree(commit),
         {:ok, mode, type, oid, path} <- Git.tree_bypath(tree, Path.join(paths)), do:
      render(conn, "browse.json", tree: tree, entry: {type, oid, path, mode})
  end

  #
  # Helpers
  #

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

  defp has_access?(user, repo, :read), do: Repo.can_read?(user, repo)
  defp has_access?(user, repo, :write), do: Repo.can_write?(user, repo)
end
