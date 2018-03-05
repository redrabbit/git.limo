defmodule GitGud.Web.RepositoryController do
  @moduledoc """
  Module responsible for CRUD actions on `GitGud.Repo`.
  """

  use GitGud.Web, :controller

  alias GitRekt.Git

  alias GitGud.User

  alias GitGud.Repo
  alias GitGud.RepoQuery

  plug :ensure_authenticated when action in [:create, :update, :delete]

  action_fallback GitGud.Web.FallbackController

  @doc """
  Returns a single repository.
  """
  @spec show(Plug.Conn.t, map) :: Plug.Conn.t
  def show(conn, %{"username" => username, "repo_name" => repo_name} = _params) do
    with {:ok, repo} <- fetch_repo({username, repo_name} , conn.assigns[:user], :read),
         {:ok, handle} <- fetch_handle(repo),
         {:ok, head} <- fetch_reference(handle, "HEAD"),
         {:ok, tree} <- fetch_tree(handle, head.oid, []),
         {:ok, branches} <- fetch_branches(handle), do:
      render(conn, "tree.html", repo: repo, branches: branches, spec: head, path: [], tree: tree)
  end

  @spec tree(Plug.Conn.t, map) :: Plug.Conn.t
  def tree(conn, %{"username" => username, "repo_name" => repo_name, "spec" => repo_spec, "path" => tree_path} = _params) do
    with {:ok, repo} <- fetch_repo({username, repo_name} , conn.assigns[:user], :read),
         {:ok, handle} <- fetch_handle(repo),
         {:ok, spec} <- fetch_reference(handle, repo_spec),
         {:ok, tree} <- fetch_tree(handle, repo_spec, tree_path),
         {:ok, branches} <- fetch_branches(handle), do:
      render(conn, "tree.html", repo: repo, branches: branches, spec: spec, path: tree_path, tree: tree)
  end

  @spec blob(Plug.Conn.t, map) :: Plug.Conn.t
  def blob(conn, %{"username" => username, "repo_name" => repo_name, "spec" => repo_spec, "path" => blob_path} = _params) do
    with {:ok, repo} <- fetch_repo({username, repo_name} , conn.assigns[:user], :read),
         {:ok, handle} <- fetch_handle(repo),
         {:ok, spec} <- fetch_reference(handle, repo_spec),
         {:ok, blob} <- fetch_blob(handle, repo_spec, blob_path),
         {:ok, branches} <- fetch_branches(handle), do:
      render(conn, "blob.html", repo: repo, branches: branches, spec: spec, path: blob_path, blob: blob)
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

  defp fetch_branches(handle) do
    with {:ok, branches} <- Git.reference_stream(handle, "refs/heads/*"), do:
      {:ok, Enum.map(branches, &transform_reference/1)}
  end

  defp fetch_commit(handle, spec) do
    with {:ok, commit, :commit, oid} <- Git.revparse_single(handle, spec), do:
      {:ok, oid, commit}
  end

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
