defmodule GitGud.GitTreeEntry do
  @moduledoc """
  Defines a Git tree entry object.
  """

  alias GitRekt.Git

  alias GitGud.Repo

  alias GitGud.GitBlob
  alias GitGud.GitTree

  @enforce_keys [:oid, :repo, :__git__]
  defstruct [:oid, :name, :mode, :type, :repo, :__git__]

  @type type :: :blob | :tree

  @type t :: %__MODULE__{oid: Git.oid, name: binary, mode: integer, type: type, repo: Repo.t, __git__: Git.blob | Git.tree}

  @doc """
  Returns the object of the `tree_entry`.
  """
  @spec object(t) :: {:ok, GitBlob.t | GitTree.t} | {:error, term}
  def object(%__MODULE__{oid: oid, type: :blob, repo: repo, __git__: blob} = _tree_entry), do: {:ok, %GitBlob{oid: oid, repo: repo, __git__: blob}}
  def object(%__MODULE__{oid: oid, type: :tree, repo: repo, __git__: tree} = _tree_entry), do: {:ok, %GitTree{oid: oid, repo: repo, __git__: tree}}
end
