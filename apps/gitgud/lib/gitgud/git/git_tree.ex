defmodule GitGud.GitTree do
  @moduledoc """
  Defines a Git tree object.
  """

  alias GitRekt.Git

  alias GitGud.Repo
  alias GitGud.GitTreeEntry

  @enforce_keys [:oid, :repo, :__git__]
  defstruct [:oid, :repo, :__git__]

  @type t :: %__MODULE__{oid: Git.oid, repo: Repo.t, __git__: Git.tree}

  @doc """
  Returns the tree entry of the given `tree`, given its `oid`.
  """
  @spec by_id(t, Git.oid) :: {:ok, GitTreeEntry.t} | {:error, term}
  def by_id(%__MODULE__{repo: repo, __git__: tree}, oid) do
    case Git.tree_byid(tree, oid) do
      {:ok, mode, type, oid, name} ->
        {:ok, resolve_entry({mode, type, oid, name}, {repo, tree})}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Returns the tree entry of the given `tree`, given its `path`.
  """
  @spec by_path(t, Path.t) :: {:ok, GitTreeEntry.t} | {:error, term}
  def by_path(%__MODULE__{repo: repo, __git__: tree}, path) do
    case Git.tree_bypath(tree, path) do
      {:ok, mode, type, oid, name} ->
        {:ok, resolve_entry({mode, type, oid, name}, {repo, tree})}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Returns all the tree entries of the given `tree`.
  """
  @spec entries(t) :: {:ok, Stream.t} | {:error, term}
  def entries(%__MODULE__{repo: repo, __git__: tree} = _tree) do
    with {:ok, stream} <- Git.tree_entries(tree),
         {:ok, stream} <- Git.enumerate(stream), do:
      {:ok, Stream.map(stream, &resolve_entry(&1, {repo, tree}))}
  end

  @doc """
  Returns `true` if `tree` matches the given `pathspec`; otherwise returns `false`.
  """
  @spec pathspec_match?(t, [binary]) :: {:ok, boolean} | {:error, term}
  def pathspec_match?(%__MODULE__{__git__: tree}, pathspec) do
    Git.pathspec_match_tree(tree, pathspec)
  end

  #
  # Helpers
  #

  defp resolve_entry({mode, type, oid, name}, {repo, tree}) do
    %GitTreeEntry{oid: oid, name: name, mode: mode, type: type, repo: repo, __git__: tree}
  end

  #
  # Protocols
  #

  defimpl Inspect do
    def inspect(tree, _opts) do
      Inspect.Algebra.concat(["#GitTree<", tree.repo.owner.login, "/", tree.repo.name, ":", Git.oid_fmt_short(tree.oid), ">"])
    end
  end
end
