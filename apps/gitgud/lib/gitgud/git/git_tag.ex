defmodule GitGud.GitTag do
  @moduledoc """
  Defines a Git tag object.
  """

  alias GitRekt.Git

  alias GitGud.Repo
  alias GitGud.GitBlob
  alias GitGud.GitCommit
  alias GitGud.GitTree

  @enforce_keys [:oid, :repo, :__git__]
  defstruct [:oid, :repo, :__git__]

  @type t :: %__MODULE__{oid: Git.oid, repo: Repo.t, __git__: Git.tag}

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
  Returns the name of the given `tag`.
  """
  @spec name(t) :: {:ok, binary} | {:error, term}
  def name(%__MODULE__{__git__: tag} = _tag) do
    Git.tag_name(tag)
  end

  @doc """
  Returns the object pointed at by `tag`.
  """
  @spec target(t) :: {:ok, Repo.git_object} | {:error, term}
  def target(%__MODULE__{repo: repo, __git__: tag} = _tag) do
    case Git.tag_peel(tag) do
      {:ok, :blob, oid, blob} ->
        {:ok, %GitBlob{oid: oid, repo: repo, __git__: blob}}
      {:ok, :commit, oid, commit} ->
        {:ok, %GitCommit{oid: oid, repo: repo, __git__: commit}}
      {:ok, :tree, oid, tree} ->
        {:ok, %GitTree{oid: oid, repo: repo, __git__: tree}}
      {:error, reason} ->
        {:error, reason}
    end
  end
end
