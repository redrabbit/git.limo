defmodule GitGud.GitTreeEntry do
  @moduledoc """
  Defines a Git tree entry object.
  """

  alias GitRekt.Git

  alias GitGud.Repo
  alias GitGud.GitBlob
  alias GitGud.GitTree

  @enforce_keys [:oid, :name, :mode, :type, :repo, :__git__]
  defstruct [:oid, :name, :mode, :type, :repo, :__git__]

  @type entry_type :: :blob | :tree

  @type t :: %__MODULE__{oid: Git.oid, name: binary, mode: integer, type: entry_type, repo: Repo.t, __git__: Git.blob | Git.tree}

  @doc """
  Returns the underlying target of the given `tree_entry`.
  """
  @spec target(t) :: {:ok, GitBlob.t | GitTree.t} | {:error, term}
  def target(%__MODULE__{oid: oid, type: type, repo: repo, __git__: tree} = _tree_entry) do
    with {:ok, handle} <- Git.object_repository(tree),
         {:ok, ^type, obj} <- Git.object_lookup(handle, oid), do:
    {:ok, struct(entry_module(type), oid: oid, repo: repo, __git__: obj)}
  end

  #
  # Helpers
  #

  defp entry_module(:blob), do: GitBlob
  defp entry_module(:tree), do: GitTree

  #
  # Protocols
  #

  defimpl Inspect do
    def inspect(tree_entry, _opts) do
      Inspect.Algebra.concat(["#GitTreeEntry<", Git.oid_fmt_short(tree_entry.oid), ">"])
    end
  end
end
