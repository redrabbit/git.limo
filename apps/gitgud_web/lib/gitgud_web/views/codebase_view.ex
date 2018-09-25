defmodule GitGud.Web.CodebaseView do
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

  @spec commit_timestamp(GitCommit.t) :: binary | nil
  def commit_timestamp(%GitCommit{} = commit) do
    case GitCommit.timestamp(commit) do
      {:ok, timestamp} ->
        Timex.format!(timestamp, "{relative}", :relative)
      {:error, _reason} -> nil
    end
  end

  @spec commit_timestamp(GitCommit.t, binary) :: binary | nil
  def commit_timestamp(%GitCommit{} = commit, format) do
    case GitCommit.timestamp(commit) do
      {:ok, timestamp} ->
        Timex.format!(timestamp, format)
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
    if message = commit_message(commit) do
      [title|_body] =  String.split(message, "\n", parts: 2)
      if String.length(title) > 50,
        do: String.slice(title, 0..49) <> "…",
      else: title
    end
  end

  @spec oid_fmt_short(Git.oid) :: binary
  def oid_fmt_short(oid), do: String.slice(oid_fmt(oid), 0..7)

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
  def title(:tree, %{repo: repo, reference: ref, tree_path: []}), do: "#{ref.shorthand} · #{repo.owner.username}/#{repo.name}"
  def title(:tree, %{repo: repo, reference: ref, tree_path: path}), do: "#{Path.join(path)} at #{ref.shorthand} · #{repo.owner.username}/#{repo.name}"
  def title(:blob, %{repo: repo, reference: ref, tree_path: path}), do: "#{Path.join(path)} at #{ref.shorthand} · #{repo.owner.username}/#{repo.name}"
end
