defmodule GitGud.GitReference do
  @moduledoc """
  Defines a Git reference object.
  """

  alias GitRekt.Git

  alias GitGud.Repo

  alias GitGud.GitCommit

  @enforce_keys [:oid, :repo, :__git__]
  defstruct [:oid, :name, :shorthand, :repo, :__git__]

  @type t :: %__MODULE__{oid: Git.oid, name: binary, shorthand: binary, repo: Repo.t, __git__: Git.repo}

  @type type :: :branch | :tag

  @doc """
  Returns the commit of the given `reference`.
  """
  @spec commit(t) :: {:ok, GitCommit.t} | {:error, term}
  def commit(%__MODULE__{oid: oid, repo: repo, __git__: handle} = _reference) do
    case Git.object_lookup(handle, oid) do
      {:ok, :commit, commit} -> {:ok, %GitCommit{oid: oid, repo: repo, __git__: commit}}
    end
  end

  @doc """
  Returns the number of commits of the given `reference`.
  """
  @spec commit_count(t) :: {:ok, non_neg_integer} | {:error, term}
  def commit_count(%__MODULE__{oid: oid, __git__: handle}) do
    with {:ok, walk} <- Git.revwalk_new(handle),
          :ok <- Git.revwalk_push(walk, oid),
         {:ok, stream} <- Git.revwalk_stream(walk), do:
      {:ok, Enum.count(stream)}
  end

  @doc """
  Returns the commit history of the given `reference`.
  """
  @spec commit_history(t) :: {:ok, [GitCommit.t]} | {:error, term}
  def commit_history(%__MODULE__{oid: oid, repo: repo, __git__: handle} = _reference) do
    with {:ok, walk} <- Git.revwalk_new(handle),
          :ok <- Git.revwalk_push(walk, oid),
         {:ok, stream} <- Git.revwalk_stream(walk), do:
      {:ok, Enum.map(stream, &resolve_commit(&1, {repo, handle}))}
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

  defp resolve_commit(oid, {repo, handle}) do
    case Git.object_lookup(handle, oid) do
      {:ok, :commit, commit} ->
        %GitCommit{oid: oid, repo: repo, __git__: commit}
      {:error, _reason} ->
        nil
    end
  end
end
