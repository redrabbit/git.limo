defmodule GitGud.Web.RepositoryController do
  @moduledoc """
  Module responsible for CRUD actions on `GitGud.Repo`.
  """

  use GitGud.Web, :controller

  alias GitRekt.Git

  alias GitGud.Repo
  alias GitGud.RepoQuery

  import GitGud.Authorization, only: [enforce_policy: 3]

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
    with {:ok, repo} <- fetch_repo(conn, {username, repo_name}, :read),
         {:ok, handle} <- fetch_handle(repo), do:
      if Git.repository_empty?(handle),
        do: render(conn, "initialize.html", repo: repo),
      else: with {:ok, spec} <- fetch_reference(handle),
                 {:ok, tree} <- fetch_tree(handle, spec),
                 {:ok, stats} <- fetch_stats(handle, spec), do:
              render(conn, "show.html", repo: repo, spec: spec, stats: stats, tree_path: [], tree: tree)
  end

  @doc """
  Renders all branches of a repository.
  """
  @spec branches(Plug.Conn.t, map) :: Plug.Conn.t
  def branches(conn, %{"username" => username, "repo_name" => repo_name} = _params) do
    with {:ok, repo} <- fetch_repo(conn, {username, repo_name}, :read),
         {:ok, handle} <- fetch_handle(repo),
         {:ok, branches} <- fetch_branches(handle), do:
      render(conn, "branch_list.html", repo: repo, branches: branches)
  end

  @doc """
  Renders all tags of a repository.
  """
  @spec tags(Plug.Conn.t, map) :: Plug.Conn.t
  def tags(conn, %{"username" => username, "repo_name" => repo_name} = _params) do
    with {:ok, repo} <- fetch_repo(conn, {username, repo_name}, :read),
         {:ok, handle} <- fetch_handle(repo),
         {:ok, tags} <- fetch_tags(handle), do:
      render(conn, "tag_list.html", repo: repo, tags: tags)
  end

  @doc """
  Renders all commits for a specific revision.
  """
  @spec commits(Plug.Conn.t, map) :: Plug.Conn.t
  def commits(conn, %{"username" => username, "repo_name" => repo_name, "spec" => repo_spec} = _params) do
    with {:ok, repo} <- fetch_repo(conn, {username, repo_name}, :read),
         {:ok, handle} <- fetch_handle(repo),
         {:ok, spec} <- fetch_reference(handle, repo_spec),
         {:ok, walk} <- fetch_revwalk(handle, spec),
         {:ok, commits} <- fetch_commits(handle, walk), do:
      render(conn, "commit_list.html", repo: repo, spec: spec, commits: commits)
  end

  def commits(conn, %{"username" => username, "repo_name" => repo_name} = _params) do
    with {:ok, repo} <- fetch_repo(conn, {username, repo_name}, :read),
         {:ok, handle} <- fetch_handle(repo),
         {:ok, spec} <- fetch_reference(handle), do:
      redirect(conn, to: repository_path(conn, :commits, username, repo, spec.shorthand))
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
    with {:ok, repo} <- fetch_repo(conn, {username, repo_name}, :read),
         {:ok, handle} <- fetch_handle(repo),
         {:ok, spec} <- fetch_reference(handle, repo_spec),
         {:ok, tree} <- fetch_tree(handle, spec),
         {:ok, stats} <- fetch_stats(handle, spec), do:
      render(conn, "show.html", repo: repo, spec: spec, stats: stats, tree_path: [], tree: tree)
  end

  def tree(conn, %{"username" => username, "repo_name" => repo_name, "spec" => repo_spec, "path" => tree_path} = _params) do
    with {:ok, repo} <- fetch_repo(conn, {username, repo_name}, :read),
         {:ok, handle} <- fetch_handle(repo),
         {:ok, spec} <- fetch_reference(handle, repo_spec),
         {:ok, tree} <- fetch_tree(handle, spec, tree_path), do:
      render(conn, "tree.html", repo: repo, spec: spec, tree_path: tree_path, tree: tree)
  end

  @doc """
  Renders a blob for a specific revision and path.
  """
  @spec blob(Plug.Conn.t, map) :: Plug.Conn.t
  def blob(conn, %{"username" => username, "repo_name" => repo_name, "spec" => repo_spec, "path" => blob_path} = _params) do
    with {:ok, repo} <- fetch_repo(conn, {username, repo_name}, :read),
         {:ok, handle} <- fetch_handle(repo),
         {:ok, spec} <- fetch_reference(handle, repo_spec),
         {:ok, blob} <- fetch_blob(handle, spec, blob_path), do:
      render(conn, "blob.html", repo: repo, spec: spec, tree_path: blob_path, blob: blob)
  end

  #
  # Helpers
  #

  defp fetch_repo(conn, {username, repo_name}, action) do
    if repo = RepoQuery.user_repository(username, repo_name),
      do: enforce_policy(current_user(conn), repo, action),
    else: {:error, :not_found}
  end

  defp fetch_handle(repo) do
    Git.repository_open(Repo.workdir(repo))
  end

  defp fetch_reference(handle) do
    with {:ok, name, shorthand, oid} <- Git.reference_resolve(handle, "HEAD"), do:
      {:ok, transform_reference({name, shorthand, :oid, oid})}
  end

  defp fetch_reference(handle, dwim) do
    with {:ok, name, type, oid} <- Git.reference_dwim(handle, dwim), do:
      {:ok, transform_reference({name, dwim, type, oid})}
  end

  defp fetch_branches(handle) do
    with {:ok, branches} <- Git.reference_stream(handle, "refs/heads/*"), do:
      {:ok, Enum.map(branches, &transform_reference/1)}
  end

  defp fetch_tags(handle) do
    with {:ok, tags} <- Git.reference_stream(handle, "refs/tags/*"), do:
      {:ok, Enum.map(tags, &transform_reference/1)}
  end

  defp fetch_commits(handle, revwalk_stream) do
    {:ok, Enum.map(revwalk_stream, &fetch_commit!(handle, &1))}
  end

  defp fetch_commit(handle, oid) do
    with {:ok, :commit, commit} <- Git.object_lookup(handle, oid),
         {:ok, message} <- Git.commit_message(commit),
         {:ok, name, email, time, tz} <- Git.commit_author(commit), do:
      {:ok, transform_commit({oid, message, name, email, time, tz})}
  end

  defp fetch_commit!(handle, oid) do
    case fetch_commit(handle, oid) do
      {:ok, commit} -> commit
    end
  end

  defp fetch_tree(handle, spec, path \\ [])
  defp fetch_tree(handle, spec, []) do
    with {:ok, :commit, commit} <- Git.object_lookup(handle, spec.__oid__),
         {:ok, _oid, tree} <- Git.commit_tree(commit),
         {:ok, entries} <- Git.tree_list(tree), do:
      {:ok, Enum.map(entries, &transform_tree_entry/1)}
  end

  defp fetch_tree(handle, spec, path) do
    with {:ok, :commit, commit} <- Git.object_lookup(handle, spec.__oid__),
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
    with {:ok, :commit, commit} <- Git.object_lookup(handle, spec.__oid__),
         {:ok, _oid, tree} <- Git.commit_tree(commit),
         {:ok, _mode, :blob, oid, _name} <- Git.tree_bypath(tree, Path.join(path)),
         {:ok, :blob, blob} <- Git.object_lookup(handle, oid),
         {:ok, content} <- Git.blob_content(blob), do:
      {:ok, content}
  end

  defp fetch_revwalk(handle, ref) do
    with {:ok, walk} <- Git.revwalk_new(handle),
          :ok <- Git.revwalk_push(walk, ref.__oid__),
         {:ok, commits} <- Git.revwalk_stream(walk), do:
      {:ok, commits}
  end

  defp fetch_stats(handle, ref) do
    with {:ok, walk} <- fetch_revwalk(handle, ref),
         {:ok, branches} <- Git.reference_stream(handle, "refs/heads/*"),
         {:ok, tags} <- Git.reference_stream(handle, "refs/tags/*"), do:
      {:ok, %{commits: Enum.count(walk), branches: Enum.count(branches), tags: Enum.count(tags)}}
  end

  defp transform_reference({name, shorthand, :oid, oid}) do
    Map.new(name: name, shorthand: shorthand, oid: Git.oid_fmt(oid), __oid__: oid)
  end

  defp transform_commit({oid, message, name, email, _time, _tz}) do
    Map.new(message: message, author: %{name: name, email: email}, oid: Git.oid_fmt(oid), __oid__: oid)
  end

  defp transform_tree_entry({mode, type, oid, name}) do
    Map.new(name: name, mode: mode, type: type, oid: Git.oid_fmt(oid), __oid__: oid)
  end
end
