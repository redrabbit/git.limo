defmodule GitGud.GitCommit do
  @moduledoc """
  Defines a Git commit object.
  """

  alias GitRekt.Git

  alias GitGud.Repo
  alias GitGud.GitTree

  @enforce_keys [:oid, :repo, :__git__]
  defstruct [:oid, :repo, :__git__]

  @type t :: %__MODULE__{oid: Git.oid, repo: Repo.t, __git__: Git.commit}

  @doc """
  Returns the author of the given `commit`.
  """
  @spec author(t) :: {:ok, {binary, binary, DateTime.t}} | {:error, term}
  def author(%__MODULE__{__git__: commit} = _commit) do
    with {:ok, name, email, time, _offset} <- Git.commit_author(commit), # TODO
         {:ok, datetime} <- DateTime.from_unix(time), do:
      {:ok, {name, email, datetime}}
  end

  @doc """
  Returns the message of the given `commit`.
  """
  @spec message(t) :: {:ok, binary} | {:error, term}
  def message(%__MODULE__{__git__: commit} = _commit) do
    Git.commit_message(commit)
  end

  @doc """
  Returns the timestamp of the given `commit`.
  """
  @spec timestamp(t) :: {:ok, DateTime.t} | {:error, term}
  def timestamp(%__MODULE__{__git__: commit} = _commit) do
    with {:ok, time, _offset} <- Git.commit_time(commit), # TODO
         {:ok, datetime} <- DateTime.from_unix(time), do:
      {:ok, struct(datetime, [])}
  end

  @doc """
  Returns the commit history starting from the given `commit`.
  """
  @spec history(t) :: {:ok, Stream.t} | {:error, term}
  def history(%__MODULE__{oid: oid, repo: repo, __git__: commit} = _commit) do
    with {:ok, handle} <- Git.object_repository(commit),
         {:ok, walk} <- Git.revwalk_new(handle),
          :ok <- Git.revwalk_push(walk, oid),
         {:ok, stream} <- Git.revwalk_stream(walk),
         {:ok, stream} <- Git.enumerate(stream), do:
      {:ok, Stream.map(stream, &resolve_commit(&1, {repo, handle}))}
  end

  @doc """
  Returns the tree of the given `commit`.
  """
  @spec tree(t) :: {:ok, GitTree.t} | {:error, term}
  def tree(%__MODULE__{repo: repo, __git__: commit} = _commit) do
    with {:ok, oid, tree} <- Git.commit_tree(commit), do:
      {:ok, %GitTree{oid: oid, repo: repo, __git__: tree}}
  end

  #
  # Helpers
  #

  defp resolve_commit(oid, {repo, handle}) do
    case Git.object_lookup(handle, oid) do
      {:ok, :commit, commit} ->
        %__MODULE__{oid: oid, repo: repo, __git__: commit}
      {:error, _reason} ->
        nil
    end
  end
end
