defmodule GitGud.GitCommit do
  @moduledoc """
  Defines a Git commit object.
  """

  alias GitRekt.Git

  alias GitGud.User
  alias GitGud.UserQuery
  alias GitGud.Repo

  alias GitGud.GitTree

  @enforce_keys [:oid, :repo, :__git__]
  defstruct [:oid, :repo, :__git__]

  @type t :: %__MODULE__{oid: Git.oid, repo: Repo.t, __git__: Git.commit}

  @doc """
  Returns the author of the given `commit`.
  """
  @spec author(t) :: {:ok, User.t} | {:error, term}
  def author(%__MODULE__{__git__: commit} = _commit) do
    with {:ok, _name, email, _time, _tz} <- Git.commit_author(commit), do:
      {:ok, UserQuery.by_email(email)}
  end

  @doc """
  Returns the message of the given `commit`.
  """
  @spec message(t) :: {:ok, binary} | {:error, term}
  def message(%__MODULE__{__git__: commit} = _commit) do
    Git.commit_message(commit)
  end

  @doc """
  Returns the tree of the given `commit`.
  """
  @spec tree(t) :: {:ok, GitTree.t} | {:error, term}
  def tree(%__MODULE__{repo: repo, __git__: commit} = _commit) do
    with {:ok, oid, tree} <- Git.commit_tree(commit), do:
      {:ok, %GitTree{oid: oid, repo: repo, __git__: tree}}
  end
end
