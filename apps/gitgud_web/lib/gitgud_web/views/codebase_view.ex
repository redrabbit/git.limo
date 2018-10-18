defmodule GitGud.Web.CodebaseView do
  @moduledoc false
  use GitGud.Web, :view

  alias GitGud.User
  alias GitGud.UserQuery

  alias GitGud.GitBlob
  alias GitGud.GitCommit
  alias GitGud.GitDiff
  alias GitGud.GitReference
  alias GitGud.GitTag
  alias GitGud.GitTree
  alias GitGud.GitTreeEntry

  import GitRekt.Git, only: [oid_fmt: 1, oid_fmt_short: 1]

  @spec batch_branches_commits_authors(Enumerable.t) :: [{GitReference.t, {GitCommit.t, User.t | map}}]
  def batch_branches_commits_authors(references_commits) do
    {references, commits} = Enum.unzip(references_commits)
    commits_authors = batch_commits_authors(commits)
    Enum.zip(references, commits_authors)
  end

  @spec batch_tags_commits_authors(Enumerable.t) :: [{GitReference.t | GitTag.t, {GitCommit.t, User.t | map}}]
  def batch_tags_commits_authors(tags_commits) do
    {tags, commits} = Enum.unzip(tags_commits)
    authors = Enum.map(tags_commits, &fetch_author/1)
    users = query_users(authors)
    Enum.zip(tags, Enum.map(Enum.zip(commits, authors), &zip_author(&1, users)))
  end

  @spec batch_commits_authors(Enumerable.t) :: [{GitCommit.t, User.t | map}]
  def batch_commits_authors(commits) do
    authors = Enum.map(commits, &fetch_author/1)
    users = query_users(authors)
    Enum.map(Enum.zip(commits, authors), &zip_author(&1, users))
  end

  @spec sort_by_commit_timestamp(Enumerable.t) :: [{GitReference.t | GitTag.t, GitCommit.t}]
  def sort_by_commit_timestamp(references_or_tags) do
    commits = Enum.map(references_or_tags, &fetch_commit/1)
    Enum.sort_by(Enum.zip(references_or_tags, commits), &commit_timestamp(elem(&1, 1)), &compare_timestamps/2)
  end

  @spec branch_select(Plug.Conn.t) :: binary
  def branch_select(conn) do
    assigns = Map.take(conn.assigns, [:repo, :revision])
    react_component("BranchSelect",
      repo: to_relay_id(assigns.repo),
      oid: revision_oid(assigns.revision),
      name: revision_name(assigns.revision),
      type: to_string(revision_type(assigns.revision))
    )
  end

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

  @spec commit_author(GitCommit.t) :: map | nil
  def commit_author(%GitCommit{} = commit) do
    case GitCommit.author(commit) do
      {:ok, author} ->
        if user = UserQuery.by_email(author.email),
          do: user,
        else: author
      {:error, _reason} -> nil
    end
  end

  @spec commit_timestamp(GitCommit.t) :: DateTime.t | nil
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

  @spec revision_oid(Repo.git_object) :: binary
  def revision_oid(%{oid: oid} = _object), do: oid_fmt(oid)

  @spec revision_name(Repo.git_object) :: binary
  def revision_name(%GitCommit{oid: oid} = _object), do: oid_fmt_short(oid)
  def revision_name(%GitTag{name: name} = _object), do: name
  def revision_name(%GitReference{name: name} = _object), do: name

  @spec revision_type(Repo.git_object) :: atom
  def revision_type(%GitCommit{} = _object), do: :commit
  def revision_type(%GitTag{} = _object), do: :tag
  def revision_type(%GitReference{} = ref) do
    case GitReference.type(ref) do
      {:ok, type} -> type
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

  @spec diff_stats(GitDiff.t) :: map | nil
  def diff_stats(%GitDiff{} = diff) do
    case GitDiff.stats(diff) do
      {:ok, stats} -> stats
      {:error, _reason} -> nil
    end
  end

  @spec diff_deltas(GitDiff.t) :: [map] | nil
  def diff_deltas(%GitDiff{} = diff) do
    case GitDiff.deltas(diff) do
      {:ok, deltas} -> deltas
      {:error, _reason} -> nil
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

  #
  # Helpers
  #

  defp fetch_commit(%GitReference{} = reference) do
    case GitReference.target(reference, :commit) do
      {:ok, commit} -> commit
      {:error, _reason} -> nil
    end
  end

  defp fetch_commit(%GitTag{} = tag) do
    case GitTag.target(tag) do
      {:ok, commit} -> commit
      {:error, _reason} -> nil
    end
  end

  defp fetch_author(%GitReference{} = reference) do
    case GitReference.target(reference, :commit) do
      {:ok, commit} ->
        fetch_author(commit)
      {:error, _reason} -> nil
    end
  end

  defp fetch_author(%GitCommit{} = commit) do
    case GitCommit.author(commit) do
      {:ok, sig} -> sig
      {:error, _reason} -> nil
    end
  end

  defp fetch_author(%GitTag{} = tag) do
    case GitTag.author(tag) do
      {:ok, sig} -> sig
      {:error, _reason} -> nil
    end
  end

  defp fetch_author({%GitReference{} = _reference, %GitCommit{} = commit}) do
    fetch_author(commit)
  end

  defp fetch_author({%GitTag{} = tag, %GitCommit{} = _commit}) do
    fetch_author(tag)
  end

  defp query_users(authors) do
    authors
    |> Enum.map(&(&1.email))
    |> Enum.uniq()
    |> UserQuery.by_email()
    |> Map.new(&{&1.email, &1})
  end

  defp compare_timestamps(one, two) do
    case DateTime.compare(one, two) do
      :gt -> true
      :eq -> false
      :lt -> false
    end
  end

  defp zip_author({parent, author}, users) do
    {parent, Map.get(users, author.email, author)}
  end
end
