defmodule GitGud.Web.RepositoryController do
  @moduledoc """
  Module responsible for CRUD actions on `GitGud.Repo`.
  """

  use GitGud.Web, :controller

  alias GitRekt.Git

  alias GitGud.User

  alias GitGud.Repo
  alias GitGud.RepoQuery

  plug :ensure_authenticated when action in [:new, :create]

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
    user = conn.assigns[:user]
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
    with {:ok, repo} <- fetch_repo({username, repo_name}, conn.assigns[:user], :read),
         {:ok, handle} <- fetch_handle(repo), do:
      if Git.repository_empty?(handle),
        do: render(conn, "init.html", repo: repo),
      else: with {:ok, spec} <- fetch_reference(handle, "HEAD"),
                 {:ok, tree} <- fetch_tree(handle, spec), do:
              render(conn, "tree.html", repo: repo, spec: spec, tree_path: [], tree: tree)
  end

  @doc """
  Renders a repository tree for a specific revision and path.
  """
  @spec tree(Plug.Conn.t, map) :: Plug.Conn.t
  def tree(conn, %{"username" => username, "repo_name" => repo_name, "spec" => repo_spec, "path" => tree_path} = _params) do
    with {:ok, repo} <- fetch_repo({username, repo_name}, conn.assigns[:user], :read),
         {:ok, handle} <- fetch_handle(repo),
         {:ok, spec} <- fetch_reference(handle, repo_spec),
         {:ok, tree} <- fetch_tree(handle, repo_spec, tree_path), do:
      render(conn, "tree.html", repo: repo, spec: spec, tree_path: tree_path, tree: tree)
  end

  def tree(conn, %{"username" => username, "repo_name" => repo_name} = _params) do
    with {:ok, repo} <- fetch_repo({username, repo_name}, conn.assigns[:user], :read),
         {:ok, handle} <- fetch_handle(repo),
         {:ok, spec} <- fetch_reference(handle, "HEAD"), do:
      redirect(conn, to: repository_path(conn, :tree, username, repo_name, spec.shorthand, []))
  end

  @doc """
  Renders a repository blob for a specific revision and path.
  """
  @spec blob(Plug.Conn.t, map) :: Plug.Conn.t
  def blob(conn, %{"username" => username, "repo_name" => repo_name, "spec" => repo_spec, "path" => blob_path} = _params) do
    with {:ok, repo} <- fetch_repo({username, repo_name}, conn.assigns[:user], :read),
         {:ok, handle} <- fetch_handle(repo),
         {:ok, spec} <- fetch_reference(handle, repo_spec),
         {:ok, blob} <- fetch_blob(handle, repo_spec, blob_path), do:
      render(conn, "blob.html", repo: repo, spec: spec, tree_path: blob_path, blob: blob)
  end

  #
  # Helpers
  #

  defp has_access?(user, repo, :read), do: Repo.can_read?(repo, user)
  defp has_access?(user, repo, :write), do: Repo.can_write?(repo, user)

  defp fetch_repo({username, repo_name}, %User{username: username}, _auth_mode) do
    if repository = RepoQuery.user_repository(username, repo_name),
      do: {:ok, repository},
    else: {:error, :not_found}
  end

  defp fetch_repo({username, repo_name}, auth_user, auth_mode) do
    with repo when not is_nil(repo) <- RepoQuery.user_repository(username, repo_name),
         true <- has_access?(auth_user, repo, auth_mode) do
      {:ok, repo}
    else
      nil   -> {:error, :not_found}
      false -> {:error, :unauthorized}
    end
  end

  defp fetch_handle(repo) do
    Git.repository_open(Repo.workdir(repo))
  end

  defp fetch_reference(handle, "HEAD" = spec) do
    with {:ok, name, shorthand, oid} <- Git.reference_resolve(handle, spec), do:
      {:ok, transform_reference({name, shorthand, :oid, oid})}
  end

  defp fetch_reference(handle, spec) do
    name = "refs/heads/#{spec}"
    with {:ok, shorthand, :oid, oid} <- Git.reference_lookup(handle, name), do:
      {:ok, transform_reference({name, shorthand, :oid, oid})}
  end

  defp fetch_commit(handle, spec) when is_map(spec) do
    with {:ok, commit, :commit, oid} <- Git.revparse_single(handle, spec.oid), do:
      {:ok, oid, commit}
  end

  defp fetch_commit(handle, spec) do
    with {:ok, commit, :commit, oid} <- Git.revparse_single(handle, spec), do:
      {:ok, oid, commit}
  end

  defp fetch_tree(handle, spec, path \\ [])
  defp fetch_tree(handle, spec, []) do
    with {:ok, _oid, commit} <- fetch_commit(handle, spec),
         {:ok, _oid, tree} <- Git.commit_tree(commit),
         {:ok, entries} <- Git.tree_list(tree), do:
      {:ok, Enum.map(entries, &transform_tree_entry/1)}
  end

  defp fetch_tree(handle, spec, path) do
    with {:ok, _oid, commit} <- fetch_commit(handle, spec),
         {:ok, _oid, tree} <- Git.commit_tree(commit),
         {:ok, _mode, :tree, oid, _name} <- Git.tree_bypath(tree, Path.join(path)),
         {:ok, :tree, tree} <- Git.object_lookup(handle, oid),
         {:ok, entries} <- Git.tree_list(tree), do:
      {:ok, Enum.map(entries, &transform_tree_entry/1)}
  end

  defp fetch_blob(_handle, _spec, []) do
    {:error, :not_found}
  end

  defp fetch_blob(handle, spec, path) do
    with {:ok, _oid, commit} <- fetch_commit(handle, spec),
         {:ok, _oid, tree} <- Git.commit_tree(commit),
         {:ok, _mode, :blob, oid, _name} <- Git.tree_bypath(tree, Path.join(path)),
         {:ok, :blob, blob} <- Git.object_lookup(handle, oid),
         {:ok, content} <- Git.blob_content(blob), do:
      {:ok, content}
  end

  defp transform_reference({name, shorthand, :oid, oid}) do
    Map.new(name: name, shorthand: shorthand, oid: Git.oid_fmt(oid))
  end

  defp transform_tree_entry({mode, type, oid, name}) do
    Map.new(mode: mode, type: type, oid: Git.oid_fmt(oid), name: name)
  end
end
