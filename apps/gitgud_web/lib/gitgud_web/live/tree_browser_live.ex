defmodule GitGud.Web.TreeBrowserLive do
  use GitGud.Web, :live_view

  alias GitRekt.GitAgent
  alias GitRekt.GitRef
  alias GitRekt.GitTreeEntry

  alias GitGud.UserQuery
  alias GitGud.RepoQuery

  alias GitGud.Repo
  alias GitGud.RepoStats

  require Logger

  import GitRekt.Git, only: [oid_fmt: 1]

  import GitGud.Web.CodebaseView

  defdelegate title(action, assigns), to: GitGud.Web.CodebaseView

  #
  # Callbacks
  #

  @impl true
  def mount(%{"user_login" => user_login, "repo_name" => repo_name} = params, session, socket) do
    {
      :ok,
      socket
      |> authenticate(session)
      |> assign_repo(user_login, repo_name)
      |> assign_agent!()
      |> assign_revision!(params["revision"])
      |> assign_stats!()
      |> assign(tree_path: params["path"] || [])
    }
  end

  @impl true
  def handle_params(params, _uri, socket) do
    send(self(), :init_tree_commits)
    {
      :noreply,
      socket
      |> assign(tree_path: params["path"] || [])
      |> assign_tree!()
    }
  end

  @impl true
  def handle_info(:init_tree_commits, socket) do
    {:noreply, assign_tree_commits!(socket)}
  end

  #
  # Helpers
  #

  defp assign_repo(socket, user_login, repo_name) do
    assign(socket, :repo, RepoQuery.user_repo(user_login, repo_name, viewer: current_user(socket), preload: :stats))
  end

  defp assign_agent!(socket) do
    case GitAgent.unwrap(socket.assigns.repo) do
      {:ok, agent} ->
        assign(socket, :agent, agent)
      {:error, reason} ->
        raise RuntimeError, message: reason
    end
  end

  defp assign_stats!(socket) do
    assign(socket, :stats, resolve_stats!(socket.assigns.repo, socket.assigns.agent, socket.assigns.revision))
  end

  defp assign_revision!(socket, nil) do
    with {:ok, head} <- GitAgent.head(socket.assigns.agent),
         {:ok, commit} <- GitAgent.peel(socket.assigns.agent, head) do
      assign(socket, revision: head, commit: commit)
    else
      {:error, reason} ->
        raise RuntimeError, message: reason
    end
  end

  defp assign_revision!(socket, revision) do
    with {:ok, {obj, ref}} <- GitAgent.revision(socket.assigns.agent, revision),
         {:ok, commit} <- GitAgent.peel(socket.assigns.agent, obj, target: :commit) do
      assign(socket, revision: ref || commit, commit: commit)
    else
      {:error, reason} ->
        raise RuntimeError, message: reason
    end
  end

  defp assign_tree!(socket) do
    commit_info = if Enum.empty?(socket.assigns.tree_path), do: resolve_tree_commit_info!(socket.assigns.agent, socket.assigns.commit)
    tree_entries = resolve_tree_entries!(socket.assigns.agent, socket.assigns.commit, socket.assigns.tree_path)
    tree_readme = Enum.find_value(tree_entries, &resolve_tree_readme!(socket.assigns.agent, &1))
    assign(socket, commit_info: commit_info, tree_entries: tree_entries, tree_readme: tree_readme)
  end

  defp assign_tree_commits!(socket) do
    {commit_info, tree_entries} = resolve_tree!(socket.assigns.agent, socket.assigns.commit, socket.assigns.tree_path)
    assign(socket, commit_info: commit_info, tree_entries: tree_entries)
  end

  defp resolve_tree_entries!(agent, commit, []) do
    case GitAgent.tree_entries(agent, commit) do
      {:ok, tree_entries} ->
        Enum.sort_by(tree_entries, fn tree_entry -> tree_entry.name end)
      {:error, reason} ->
        raise RuntimeError, message: reason
    end
  end

  defp resolve_tree_entries!(agent, commit, tree_path) do
    case GitAgent.tree_entries(agent, commit, path: Path.join(tree_path)) do
      {:ok, tree_entries} ->
        Enum.sort_by(tree_entries, fn tree_entry -> tree_entry.name end)
      {:error, reason} ->
        raise RuntimeError, message: reason
    end
  end

  defp resolve_tree!(agent, commit, []) do
    case GitAgent.tree_entries(agent, commit, with: :commit) do
      {:ok, tree_entries} ->
        {
          resolve_tree_commit_info!(agent, commit),
          tree_entries
          |> Enum.map(&resolve_tree_entry_commit_info!(agent, &1))
          |> Enum.sort_by(fn {tree_entry, _commit} -> tree_entry.name end)
        }
      {:error, reason} ->
        raise RuntimeError, message: reason
    end
  end

  defp resolve_tree!(agent, commit, tree_path) do
    case GitAgent.tree_entries(agent, commit, path: Path.join(tree_path), with: :commit) do
      {:ok, tree_entries} ->
        [{_tree_entry, commit}|tree_entries] = Enum.to_list(tree_entries)
        {
          resolve_tree_commit_info!(agent, commit),
          tree_entries
          |> Enum.map(&resolve_tree_entry_commit_info!(agent, &1))
          |> Enum.sort_by(fn {tree_entry, _commit} -> tree_entry.name end)
        }
      {:error, reason} ->
        raise RuntimeError, message: reason
    end
  end

  defp resolve_tree_commit_info!(agent, commit) do
    case GitAgent.transaction(agent, &resolve_tree_commit_info(&1, commit)) do
      {:ok, commit_info} ->
        resolve_commit_info_db(commit_info)
      {:error, reason} ->
        raise RuntimeError, message: reason
    end
  end

  defp resolve_tree_commit_info(agent, commit) do
    with {:ok, message} <- GitAgent.commit_message(agent, commit),
         {:ok, timestamp} <- GitAgent.commit_timestamp(agent, commit),
         {:ok, author} <- GitAgent.commit_author(agent, commit),
         {:ok, committer} <- GitAgent.commit_committer(agent, commit), do:
      {:ok, %{oid: commit.oid, message: message, timestamp: timestamp, author: author, committer: committer}}
  end

  defp resolve_tree_entry_commit_info!(agent, {tree_entry, commit}) do
    case GitAgent.transaction(agent, &resolve_tree_entry_commit_info(&1, commit)) do
      {:ok, commit_info} ->
        {tree_entry, commit_info}
      {:error, reason} ->
        raise RuntimeError, message: reason
    end
  end

  defp resolve_tree_entry_commit_info(agent, commit) do
    with {:ok, message} <- GitAgent.commit_message(agent, commit),
         {:ok, timestamp} <- GitAgent.commit_timestamp(agent, commit), do:
      {:ok, %{oid: commit.oid, message: message, timestamp: timestamp}}
  end

  defp resolve_tree_readme!(agent, %GitTreeEntry{type: :blob, name: "README.md" = name} = tree_entry) do
    {:ok, blob} = GitAgent.peel(agent, tree_entry)
    {:ok, blob_content} = GitAgent.blob_content(agent, blob)
    {GitGud.Web.Markdown.markdown_safe(blob_content), name}
  end

  defp resolve_tree_readme!(agent, %GitTreeEntry{type: :blob, name: "README" = name} = tree_entry) do
    {:ok, blob} = GitAgent.peel(agent, tree_entry)
    {:ok, blob_content} = GitAgent.blob_content(agent, blob)
    {blob_content, name}
  end

  defp resolve_tree_readme!(_agent, %GitTreeEntry{}), do: nil

  defp resolve_commit_info_db(%{author: %{email: email}, committer: %{email: email}} = commit_info) do
      if user = UserQuery.by_email(email),
        do: %{commit_info|author: user, committer: user},
      else: commit_info
  end

  defp resolve_commit_info_db(%{author: author, committer: committer} = commit_info) do
    users = UserQuery.by_email([author.email, committer.email])
    %{commit_info|author: resolve_user(author, users), committer: resolve_user(committer, users)}
  end

  defp resolve_user(%{email: email} = map, users) do
    Enum.find(users, map, fn user -> email in Enum.map(user.emails, &(&1.address)) end)
  end

  defp resolve_stats!(%Repo{stats: %RepoStats{refs: stats_refs}} = repo, agent, revision) when is_map(stats_refs) do
    rev_stats =
      case revision do
        %GitRef{} = ref ->
          Map.get(stats_refs, to_string(ref), %{})
        rev ->
          case GitAgent.history_count(agent, rev) do
            {:ok, commit_count} ->
              %{"count" => commit_count}
            {:error, reason} ->
              raise RuntimeError, message: reason
          end
      end
    rev_groups = Enum.group_by(stats_refs, fn {"refs/" <> ref_name_suffix, _stats} -> hd(Path.split(ref_name_suffix)) end)
    %{
      branches: Enum.count(Map.get(rev_groups, "heads", [])),
      tags: Enum.count(Map.get(rev_groups, "tags", [])),
      commits: rev_stats["count"] || 0,
      contributors: RepoQuery.count_contributors(repo)
    }
  end

  defp resolve_stats!(%Repo{} = repo, agent, revision) do
    Logger.warn("repository #{repo.owner.login}/#{repo.name} does not have stats")
    with {:ok, branches} <- GitAgent.branches(agent),
         {:ok, tags} <- GitAgent.tags(agent),
         {:ok, commit_count} <- GitAgent.history_count(agent, revision) do
      %{
        branches: Enum.count(branches),
        tags: Enum.count(tags),
        commits: commit_count,
        contributors: RepoQuery.count_contributors(repo)
      }
    else
      {:error, reason} ->
        raise RuntimeError, message: reason
    end
  end
end
