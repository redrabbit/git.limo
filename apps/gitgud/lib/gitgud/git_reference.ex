defmodule GitGud.GitReference do
  @moduledoc """
  Defines a Git reference object.
  """

  alias GitRekt.Git

  alias GitGud.GitCommit

  defstruct [:oid, :name, :shorthand, :__git__]

  @type t :: %__MODULE__{
    __git__: Git.repo,
    oid: Git.oid,
    name: binary,
    shorthand: binary
  }

  @type reference_type :: :branch | :tag

  @doc """
  Returns the underlying object of the given `reference`.
  """
  @spec object(t) :: {:ok, GitCommit.t} | {:error, term}
  def object(%__MODULE__{oid: oid, __git__: handle} = _reference) do
    case Git.object_lookup(handle, oid) do
      {:ok, :commit, commit} -> {:ok, %GitCommit{oid: oid, __git__: commit}}
    end
  end

  @doc """
  Returns the type of the given `reference`.
  """
  @spec type(t) :: {:ok, reference_type} | {:error, term}
  def type(%__MODULE__{name: "refs/heads/" <> shorthand, shorthand: shorthand} = _reference), do: {:ok, :branch}
  def type(%__MODULE__{name: "refs/tags/" <> shorthand, shorthand: shorthand} = _reference), do: {:ok, :tag}
  def type(%__MODULE__{} = _reference), do: {:error, :invalid_reference}
end
