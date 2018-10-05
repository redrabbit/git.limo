defmodule GitGud.GitCommit do
  @moduledoc """
  Defines a Git commit object.
  """

  alias GitRekt.Git

  alias GitGud.Repo

  @enforce_keys [:oid, :repo, :__git__]
  defstruct [:oid, :repo, :__git__]

  @type t :: %__MODULE__{oid: Git.oid(), repo: Repo.t(), __git__: Git.commit()}

  @doc """
  Returns the author of the given `commit`.
  """
  @spec author(t) :: {:ok, {binary, binary, DateTime.t()}} | {:error, term}
  def author(%__MODULE__{__git__: commit} = _commit) do
    # TODO
    with {:ok, name, email, time, _offset} <- Git.commit_author(commit),
         {:ok, datetime} <- DateTime.from_unix(time),
         do: {:ok, {name, email, datetime}}
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
  @spec timestamp(t) :: {:ok, DateTime.t()} | {:error, term}
  def timestamp(%__MODULE__{__git__: commit} = _commit) do
    # TODO
    with {:ok, time, _offset} <- Git.commit_time(commit),
         {:ok, datetime} <- DateTime.from_unix(time),
         do: {:ok, struct(datetime, [])}
  end
end
