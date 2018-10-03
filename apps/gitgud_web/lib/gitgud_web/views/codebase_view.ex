defmodule GitGud.Web.CodebaseView do
  @moduledoc false
  use GitGud.Web, :view

  alias GitGud.GitBlob
  alias GitGud.GitCommit
  alias GitGud.GitReference
  alias GitGud.GitTree
  alias GitGud.GitTreeEntry

  import GitRekt.Git, only: [oid_fmt: 1, oid_fmt_short: 1]

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

  @spec commit_author(GitCommit.t) :: {binary, binary} | nil
  def commit_author(%GitCommit{} = commit) do
    case GitCommit.author(commit) do
      {:ok, {name, email, _datetime}} -> {name, email}
      {:error, _reason} -> nil
    end
  end

  @spec commit_timestamp(GitCommit.t) :: binary | nil
  def commit_timestamp(%GitCommit{} = commit) do
    case GitCommit.timestamp(commit) do
      {:ok, timestamp} -> timestamp
      {:error, _reason} -> nil
    end
  end

  @spec commit_message(GitCommit.t) :: binary | nil
  def commit_message(%GitCommit{} = commit) do
    case GitCommit.message(commit) do
      {:ok, message} -> message
      {:error, _reason} -> nil
    end
  end

  @spec commit_message_title(GitCommit.t) :: binary | nil
  def commit_message_title(%GitCommit{} = commit) do
    case GitCommit.message(commit) do
      {:ok, message} -> hd(String.split(message, "\n", parts: 2))
      {:error, _reason} -> nil
    end
  end

  @spec reference_type(GitReference.t) :: binary
  def reference_type(%GitReference{} = ref) do
    case GitReference.type(ref) do
      {:ok, type} -> to_string(type)
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

  @spec title(atom, map) :: binary
  def title(:show, %{repo: repo}), do: "#{repo.description} · #{repo.owner.username}/#{repo.name}"
  def title(:branches, %{repo: repo}), do: "Branches · #{repo.owner.username}/#{repo.name}"
  def title(:tags, %{repo: repo}), do: "Tags · #{repo.owner.username}/#{repo.name}"
  def title(:commits, %{repo: repo}), do: "Commits · #{repo.owner.username}/#{repo.name}"
  def title(:commit, %{repo: repo, commit: commit}), do: "#{commit_message_title(commit)} · #{repo.owner.username}/#{repo.name}@#{oid_fmt_short(commit.oid)}"
  def title(:tree, %{repo: repo, reference: ref, tree_path: []}), do: "#{ref.name} · #{repo.owner.username}/#{repo.name}"
  def title(:tree, %{repo: repo, reference: ref, tree_path: path}), do: "#{Path.join(path)} at #{ref.name} · #{repo.owner.username}/#{repo.name}"
  def title(:blob, %{repo: repo, reference: ref, tree_path: path}), do: "#{Path.join(path)} at #{ref.name} · #{repo.owner.username}/#{repo.name}"
end
