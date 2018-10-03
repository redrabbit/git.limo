defmodule GitGud.GitTag do
  @moduledoc """
  Defines a Git tag object.
  """

  alias GitRekt.Git

  alias GitGud.Repo
  alias GitGud.GitBlob
  alias GitGud.GitCommit
  alias GitGud.GitRevision
  alias GitGud.GitTree

  @enforce_keys [:oid, :name, :repo, :__git__]
  defstruct [:oid, :name, :repo, :__git__]

  @type t :: %__MODULE__{oid: Git.oid, name: binary, repo: Repo.t, __git__: Git.tag}

  @doc """
  Returns the author of the given `tag`.
  """
  @spec author(t) :: {:ok, {binary, binary, DateTime.t}} | {:error, term}
  def author(%__MODULE__{__git__: tag} = _tag) do
    with {:ok, name, email, time, _offset} <- Git.tag_author(tag), # TODO
         {:ok, datetime} <- DateTime.from_unix(time), do:
      {:ok, {name, email, datetime}}
  end

  @doc """
  Returns the message of the given `tag`.
  """
  @spec message(t) :: {:ok, binary} | {:error, term}
  def message(%__MODULE__{__git__: tag} = _tag) do
    Git.tag_message(tag)
  end

  @doc """
  Returns the object pointed at by `tag`.
  """
  @spec target(t) :: {:ok, Repo.git_object} | {:error, term}
  def target(%__MODULE__{repo: repo, __git__: tag} = _tag) do
    case Git.tag_peel(tag) do
      {:ok, :commit, oid, commit} ->
        {:ok, %GitCommit{oid: oid, repo: repo, __git__: commit}}
      {:ok, :tree, oid, tree} ->
        {:ok, %GitTree{oid: oid, repo: repo, __git__: tree}}
      {:ok, :blob, oid, blob} ->
        {:ok, %GitBlob{oid: oid, repo: repo, __git__: blob}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defimpl GitRevision do
    alias GitGud.GitTag

    def history(%GitTag{oid: oid, repo: repo, __git__: tag} = _reference) do
      with {:ok, handle} <- Git.object_repository(tag),
           {:ok, walk} <- Git.revwalk_new(handle),
            :ok <- Git.revwalk_push(walk, oid),
           {:ok, stream} <- Git.revwalk_stream(walk),
           {:ok, stream} <- Git.enumerate(stream), do:
        {:ok, Stream.map(stream, &resolve_commit(&1, {repo, handle}))}
    end

    def tree(%GitTag{repo: repo, __git__: tag} = _tag) do
      with {:ok, :commit, _oid, commit} <- Git.tag_peel(tag),
           {:ok, oid, tree} <- Git.commit_tree(commit), do:
        {:ok, %GitTree{oid: oid, repo: repo, __git__: tree}}
    end

    defp resolve_commit(oid, {repo, handle}) do
      case Git.object_lookup(handle, oid) do
        {:ok, :commit, commit} ->
          %GitCommit{oid: oid, repo: repo, __git__: commit}
        {:error, _reason} ->
          nil
      end
    end
  end
end
