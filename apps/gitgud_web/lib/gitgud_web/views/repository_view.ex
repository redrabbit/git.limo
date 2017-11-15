defmodule GitGud.Web.RepositoryView do
  @moduledoc false
  use GitGud.Web, :view

  alias GitRekt.Git

  def render("index.json", %{repositories: repositories}) do
    %{repositories: render_many(repositories, __MODULE__, "repository.json")}
  end

  def render("show.json", %{repository: repository}) do
    %{repository: render_one(repository, __MODULE__, "repository.json")}
  end

  def render("branches.json", %{refs: refs}) do
    %{branches: render_many(refs, __MODULE__, "branch.json", as: :branch)}
  end

  def render("commits.json", %{revwalk: walk}) do
    {:ok, handle} = Git.revwalk_repository(walk)
    commits = render_many(Enum.map(Git.revwalk_stream(walk), &resolve_revwalk_commit(&1, handle)), __MODULE__, "commit.json", as: :commit)
    %{commits: commits}
  end

  def render("browse.json", %{tree: tree, entry: {:blob, oid, path, mode}}) do
    {:ok, handle} = Git.tree_repository(tree)
    {:ok, :blob, blob} = Git.object_lookup(handle, oid)
    entry = render_one({:blob, blob, path, mode}, __MODULE__, "tree.json", as: :tree)
    %{blob: entry}
  end

  def render("browse.json", %{tree: tree, entry: {:tree, oid, path, mode}}) do
    {:ok, handle} = Git.tree_repository(tree)
    {:ok, :tree, tree} = Git.object_lookup(handle, oid)
    entry = render_one({:tree, tree, path, mode}, __MODULE__, "tree.json", as: :tree)
    leafs = render_many(Enum.map(Git.tree_list(tree), &resolve_tree_entry(&1, handle)), __MODULE__, "tree.json", as: :tree)
    %{tree: Map.put(entry, :tree, leafs)}
  end

  def render("browse.json", %{tree: tree}) do
    {:ok, handle} = Git.tree_repository(tree)
    entry = render_one({:tree, tree, "/", 16384}, __MODULE__, "tree.json", as: :tree)
    leafs = render_many(Enum.map(Git.tree_list(tree), &resolve_tree_entry(&1, handle)), __MODULE__, "tree.json", as: :tree)
    %{tree: Map.put(entry, :tree, leafs)}
  end

  def render("repository.json", %{repository: repository}) do
    %{owner: repository.owner.username,
      name: repository.name,
      path: repository.path,
      description: repository.description}
  end

  def render("branch.json", %{branch: {_ref, shorthand, :oid, oid}}) do
    %{sha: Git.oid_fmt(oid), name: shorthand}
  end

  def render("commit.json", %{commit: {oid, commit}}) do
    {:ok, message} = Git.commit_message(commit)
    %{sha: Git.oid_fmt(oid), message: message}
  end

  def render("tree.json", %{tree: {:blob, nil, path, mode}}) do
    %{type: :blob, path: path, mode: mode}
  end

  def render("tree.json", %{tree: {:blob, blob, path, mode}}) do
    {:ok, data} = Git.blob_content(blob)
    %{type: :blob, path: path, mode: mode, blob: data}
  end

  def render("tree.json", %{tree: {:tree, _tree, path, mode}}) do
    %{type: :tree, path: path, mode: mode}
  end

  #
  # Helpers
  #

  defp resolve_tree_entry({mode, type, _oid, path}, _handle) do
    {type, nil, path, mode}
  end

  defp resolve_revwalk_commit(oid, handle) do
    {:ok, :commit, commit} = Git.object_lookup(handle, oid)
    {oid, commit}
  end
end
