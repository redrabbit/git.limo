defmodule GitGud.Web.RepositoryView do
  @moduledoc false
  use GitGud.Web, :view

  alias GitRekt.Git

  def render("index.json", %{repositories: repositories}) do
    %{data: render_many(repositories, __MODULE__, "repository.json")}
  end

  def render("show.json", %{repository: repository}) do
    %{data: render_one(repository, __MODULE__, "repository.json")}
  end

  def render("browse.json", %{tree: tree, entry: {:blob, oid, path, mode}}) do
    {:ok, handle} = Git.tree_repository(tree)
    {:ok, :blob, blob} = Git.object_lookup(handle, oid)
    entry = render_one({:blob, blob, path, mode}, __MODULE__, "tree.json", as: :tree)
    %{data: entry}
  end

  def render("browse.json", %{tree: tree, entry: {:tree, oid, path, mode}}) do
    {:ok, handle} = Git.tree_repository(tree)
    {:ok, :tree, tree} = Git.object_lookup(handle, oid)
    entry = render_one({:tree, tree, path, mode}, __MODULE__, "tree.json", as: :tree)
    leafs = render_many(Enum.map(Git.tree_list(tree), &map_tree_entry(handle, &1)), __MODULE__, "tree.json", as: :tree)
    %{data: Map.put(entry, :tree, leafs)}
  end

  def render("browse.json", %{tree: tree}) do
    {:ok, handle} = Git.tree_repository(tree)
    entry = render_one({:tree, tree, "/", 16384}, __MODULE__, "tree.json", as: :tree)
    leafs = render_many(Enum.map(Git.tree_list(tree), &map_tree_entry(handle, &1)), __MODULE__, "tree.json", as: :tree)
    %{data: Map.put(entry, :tree, leafs)}
  end

  def render("repository.json", %{repository: repository}) do
    %{owner: repository.owner.username,
      name: repository.name,
      path: repository.path,
      description: repository.description}
  end

  def render("tree.json", %{tree: {:blob, blob, path, mode}}) do
    unless is_nil(blob) do
      {:ok, data} = Git.blob_content(blob)
      %{type: :blob, path: path, mode: mode, blob: data}
    else
      %{type: :blob, path: path, mode: mode}
    end
  end

  def render("tree.json", %{tree: {:tree, _tree, path, mode}}) do
    %{type: :tree, path: path, mode: mode}
  end

  #
  # Helpers
  #

  defp map_tree_entry(_handle, {mode, type, _oid, path}) do
  # {:ok, ^type, obj} = Git.object_lookup(handle, oid)
  # {type, obj, path, mode}
    {type, nil, path, mode}
  end
end
