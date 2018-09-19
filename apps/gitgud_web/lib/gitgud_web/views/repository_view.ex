defmodule GitGud.Web.RepositoryView do
  @moduledoc false
  use GitGud.Web, :view

  alias GitGud.GitBlob
  alias GitGud.GitCommit
  alias GitGud.GitTree
  alias GitGud.GitTreeEntry

  import GitRekt.Git, only: [oid_fmt: 1]

  @spec blob_content(GitBlob.t) :: binary | nil
  def blob_content(%GitBlob{} = blob) do
    case GitBlob.content(blob) do
      {:ok, content} -> content
      {:error, _reason} -> nil
    end
  end

  @spec blob_size(GitBlob.t) :: non_neg_integer | nil
  def blob_size(%GitBlob{} = blob) do
    case GitBlob.size(blob) do
      {:ok, size} -> size
      {:error, _reason} -> nil
    end
  end

  @spec commit_author(GitCommit.t) :: User.t | nil
  def commit_author(%GitCommit{} = commit) do
    case GitCommit.author(commit) do
      {:ok, author} -> author
      {:error, _reason} -> nil
    end
  end

  @spec commit_message(GitCommit.t) :: User.t | nil
  def commit_message(%GitCommit{} = commit) do
    case GitCommit.message(commit) do
      {:ok, author} -> author
      {:error, _reason} -> nil
    end
  end

  @spec tree_entries(GitTree.t) :: [GitTreeEntry.t]
  def tree_entries(%GitTree{} = tree) do
    case GitTree.entries(tree) do
      {:ok, entries} -> entries
      {:error, _reason} -> []
    end
  end
end
