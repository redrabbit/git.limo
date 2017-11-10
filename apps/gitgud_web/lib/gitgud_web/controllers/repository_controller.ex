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
    case fetch({username, path}, conn.assigns[:user], :read) do
      {:ok, repo} -> render(conn, "show.json", repository: repo)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Browses a repository's tree by path.
  """
  def browse(conn, %{"user" => username, "repo" => path, "dwim" => shorthand, "path" => paths} = _params) do
    with {:ok, repo} <- fetch({username, path} , conn.assigns[:user], :read),
         {:ok, handle} <- Git.repository_open(Repo.workdir(repo)),
         {:ok, _ref, :oid, oid} <- Git.reference_dwim(handle, shorthand),
         {:ok, :commit, commit} <- Git.object_lookup(handle, oid),
         {:ok, _oid, tree} <- Git.commit_tree(commit),
         {:ok, _mode, :blob, oid, _name} <- Git.tree_bypath(tree, Path.join(paths)),
         {:ok, :blob, blob} <- Git.object_lookup(handle, oid),
         {:ok, data} <- Git.blob_content(blob), do:
      json(conn, %{"size" => Git.blob_size(blob), "data" => data})
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
    with {:ok, repo} <- fetch({username, path}, conn.assigns[:user], :write),
         {:ok, repo} <- Repo.update(repo, repo_params), do:
      render(conn, "show.json", repository: repo)
  end

  @doc """
  Deletes an existing repository.
  """
  @spec delete(Plug.Conn.t, map) :: Plug.Conn.t
  def delete(conn, %{"user" => username, "repo" => path} = _params) do
    with {:ok, repo} <- fetch({username, path}, conn.assigns[:user], :write),
         {:ok, _del} <- Repo.delete(repo), do:
      send_resp(conn, :no_content, "")
  end

  #
  # Helpers
  #

  defp fetch({username, path}, %User{username: username}, _auth_mode) do
    if repository = RepoQuery.user_repository(username, path),
      do: {:ok, repository},
    else: {:error, :not_found}
  end

  defp fetch({username, path}, auth_user, auth_mode) do
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
