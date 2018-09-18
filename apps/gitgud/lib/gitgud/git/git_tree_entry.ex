defmodule GitGud.GitTreeEntry do
  @moduledoc """
  Defines a Git tree entry object.
  """

  alias GitRekt.Git

  alias GitGud.GitBlob
  alias GitGud.GitTree

  defstruct [:oid, :name, :mode, :type, :__git__]

  @type type :: :blob | :tree

  @type t :: %__MODULE__{
    __git__: Git.blob | Git.tree,
    oid: Git.oid,
    name: binary,
    mode: integer,
    type: type
  }

  @doc """
  Returns the object of the `tree_entry`.
  """
  @spec object(t) :: {:ok, GitBlob.t | GitTree.t} | {:error, term}
  def object(%__MODULE__{oid: oid, type: :blob, __git__: blob} = _tree_entry), do: {:ok, %GitBlob{oid: oid, __git__: blob}}
  def object(%__MODULE__{oid: oid, type: :tree, __git__: tree} = _tree_entry), do: {:ok, %GitTree{oid: oid, __git__: tree}}
end
