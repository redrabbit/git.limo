defmodule GitGud.GitReference do
  @moduledoc """
  Defines a Git reference object.
  """

  alias GitRekt.Git

  alias GitGud.GitCommit

  defstruct [:oid, :name, :shorthand, :__git__]

  @type t :: %__MODULE__{oid: Git.oid, name: binary, shorthand: binary, __git__: Git.repo}

  @type type :: :branch | :tag

  @doc """
  Returns the commit of the given `reference`.
  """
  @spec commit(t) :: {:ok, GitCommit.t} | {:error, term}
  def commit(%__MODULE__{oid: oid, __git__: handle} = _reference) do
    case Git.object_lookup(handle, oid) do
      {:ok, :commit, commit} -> {:ok, %GitCommit{oid: oid, __git__: commit}}
    end
  end

  @doc """
  Returns the commit history of the given `reference`.
  """
  @spec commit_history(t) :: {:ok, [GitCommit.t]} | {:error, term}
  def commit_history(%__MODULE__{oid: oid, __git__: handle} = _reference) do
    with {:ok, walk} <- Git.revwalk_new(handle),
          :ok <- Git.revwalk_push(walk, oid),
         {:ok, stream} <- Git.revwalk_stream(walk), do:
      {:ok, Enum.map(stream, &resolve_commit(&1, handle))}
  end

  @doc """
  Returns the type of the given `reference`.
  """
  @spec type(t) :: {:ok, type} | {:error, term}
  def type(%__MODULE__{name: "refs/heads/" <> shorthand, shorthand: shorthand} = _reference), do: {:ok, :branch}
  def type(%__MODULE__{name: "refs/tags/" <> shorthand, shorthand: shorthand} = _reference), do: {:ok, :tag}
  def type(%__MODULE__{} = _reference), do: {:error, :invalid_reference}

  #
  # Helpers
  #

  defp resolve_commit(oid, handle) do
    case Git.object_lookup(handle, oid) do
      {:ok, :commit, commit} ->
        %GitCommit{oid: oid, __git__: commit}
      {:error, _reason} ->
        nil
    end
  end
end
