defmodule GitGud.GitBlob do
  @moduledoc """
  Defines a Git blob object.
  """

  alias GitRekt.Git

  alias GitGud.Repo

  @enforce_keys [:oid, :repo, :__git__]
  defstruct [:oid, :repo, :__git__]

  @type t :: %__MODULE__{oid: Git.oid, repo: Repo.t, __git__: Git.blob}

  @doc """
  Returns the content of the given `blob`.
  """
  @spec content(t) :: {:ok, binary} | {:error, term}
  def content(%__MODULE__{__git__: blob} = _blob) do
    Git.blob_content(blob)
  end

  @doc """
  Returns the size in bytes of the given `blob`.
  """
  @spec size(t) :: {:ok, non_neg_integer} | {:error, term}
  def size(%__MODULE__{__git__: blob} = _blob) do
    Git.blob_size(blob)
  end
end
