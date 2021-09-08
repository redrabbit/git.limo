defmodule GitGud.Web.TreeBrowserLive do
  @moduledoc """
  Live view responsible for rendering Git tree objects.
  """

  use GitGud.Web, :live_view

  alias GitRekt.GitAgent
  alias GitRekt.GitTreeEntry

  alias GitGud.DB
  alias GitGud.DBQueryable

  alias GitGud.UserQuery
  alias GitGud.RepoQuery

  import GitRekt.Git, only: [oid_fmt: 1]

  import GitGud.Web.CodebaseView

  #
  # Callbacks
  #

  @impl true
  def mount(%{"user_login" => user_login, "repo_name" => repo_name} = params, session, socket) do
    {
      :ok,
      socket
      |> authenticate(session)
      |> assign(:stats, %{})
      |> assign_repo!(user_login, repo_name)
      |> assign_repo_open_issue_count()
      |> assign_agent!()
      |> assign_revision!(params["revision"])
    }
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {
      :noreply,
      socket
      |> assign(tree_path: params["path"] || [])
      |> assign_tree!()
      |> assign_tree_commits_async()
      |> assign_stats!()
      |> assign_page_title()
    }
  end

  @impl true
  def handle_info(:assign_tree_commits, socket) do
    {:noreply, assign_tree_commits!(socket)}
  end

  #
  # Helpers
  #

  defp assign_repo!(socket, user_login, repo_name) do
    query = DBQueryable.query({RepoQuery, :user_repo_query}, [user_login, repo_name], viewer: current_user(socket))
    assign(socket, :repo, DB.one!(query))
  end

  defp assign_agent!(socket) do
    case GitAgent.unwrap(socket.assigns.repo) do
      {:ok, agent} ->
        assign(socket, :agent, agent)
      {:error, error} ->
        raise error
    end
  end

  defp assign_repo_open_issue_count(socket) do
    assign(socket, :repo_open_issue_count, GitGud.IssueQuery.count_repo_issues(socket.assigns.repo, status: :open))
  end

  defp assign_revision!(socket, nil) do
    with {:ok, false} <- GitAgent.empty?(socket.assigns.agent),
         {:ok, head} <- GitAgent.head(socket.assigns.agent),
         {:ok, commit} <- GitAgent.peel(socket.assigns.agent, head) do
      assign(socket, revision_spec: nil, revision: head, commit: commit)
    else
      {:ok, true} ->
        assign(socket, revision_spec: nil, revision: nil, commit: nil)
      {:error, error} ->
        raise error
    end
  end

  defp assign_revision!(socket, rev_spec) do
    with {:ok, {obj, ref}} <- GitAgent.revision(socket.assigns.agent, rev_spec),
         {:ok, commit} <- GitAgent.peel(socket.assigns.agent, obj, target: :commit) do
      assign(socket, revision_spec: rev_spec, revision: ref || commit, commit: commit)
    else
      {:error, error} ->
        raise error
    end
  end

  defp assign_tree!(socket) when is_nil(socket.assigns.revision), do: socket
  defp assign_tree!(socket) do
    tree_commit_info =
      if Enum.empty?(socket.assigns.tree_path) do
        socket.assigns.agent
        |> resolve_tree_commit_info!(socket.assigns.commit)
        |> resolve_commit_info_db()
      end
    tree_entries = resolve_tree_entries!(socket.assigns.agent, socket.assigns.commit, socket.assigns.tree_path)
    tree_readme = Enum.find_value(tree_entries, &resolve_tree_readme!(socket.assigns.agent, &1))
    assign(socket, tree_commit_info: tree_commit_info, tree_entries: Enum.map(tree_entries, &{&1, nil}), tree_readme: tree_readme)
  end

  defp assign_tree_commits_async(socket) do
    if connected?(socket) do
      send(self(), :assign_tree_commits)
    end
    socket
  end

  defp assign_tree_commits!(socket) when is_nil(socket.assigns.revision), do: socket
  defp assign_tree_commits!(socket) do
    {tree_commit_info, tree_entries} = resolve_tree!(socket.assigns.agent, socket.assigns.commit, socket.assigns.tree_path)
    assign(socket, tree_commit_info: tree_commit_info, tree_entries: tree_entries)
  end

  defp assign_stats!(socket) when is_nil(socket.assigns.revision) or socket.assigns.tree_path != [] or socket.assigns.stats != %{}, do: socket
  defp assign_stats!(socket) do
    stats = resolve_stats!(socket.assigns.agent, socket.assigns.revision)
    stats = Map.put(stats, :contributors, RepoQuery.count_contributors(socket.assigns.repo))
    assign(socket, :stats, stats)
  end

  defp assign_page_title(socket) do
    assign(socket, :page_title, GitGud.Web.CodebaseView.title(socket.assigns[:live_action], socket.assigns))
  end

  defp resolve_tree_entries!(agent, commit, []) do
    case GitAgent.tree_entries(agent, commit) do
      {:ok, tree_entries} ->
        Enum.sort_by(tree_entries, &(&1.name))
      {:error, error} ->
        raise error
    end
  end

  defp resolve_tree_entries!(agent, commit, tree_path) do
    case GitAgent.tree_entries(agent, commit, path: Path.join(tree_path)) do
      {:ok, tree_entries} ->
        Enum.sort_by(tree_entries, &(&1.name))
      {:error, error} ->
        raise error
    end
  end

  defp resolve_tree!(agent, commit, tree_path) do
    case GitAgent.transaction(agent, {:tree_entries_with_commit, commit.oid, tree_path}, &resolve_tree(&1, commit, tree_path)) do
      {:ok, {commit_info, tree_entries}} ->
        {
          resolve_commit_info_db(commit_info),
          tree_entries
        }
      {:error, error} ->
        raise error
    end
  end

  defp resolve_tree(agent, commit, []) do
    case GitAgent.tree_entries(agent, commit, with: :commit) do
      {:ok, tree_entries} ->
        {
          :ok,
          {
            resolve_tree_commit_info!(agent, commit),
            tree_entries
            |> Enum.map(&resolve_tree_entry_commit_info!(agent, &1))
            |> Enum.sort_by(fn {tree_entry, _commit} -> tree_entry.name end)
          }
        }
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp resolve_tree(agent, commit, tree_path) do
    case GitAgent.tree_entries(agent, commit, path: Path.join(tree_path), with: :commit) do
      {:ok, tree_entries} ->
        [{_tree_entry, commit}|tree_entries] = Enum.to_list(tree_entries)
        {
          :ok,
          {
            resolve_tree_commit_info!(agent, commit),
            tree_entries
            |> Enum.map(&resolve_tree_entry_commit_info!(agent, &1))
            |> Enum.sort_by(fn {tree_entry, _commit} -> tree_entry.name end)
          }
        }
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp resolve_tree_commit_info!(agent, commit) do
    case GitAgent.transaction(agent, &resolve_tree_commit_info(&1, commit)) do
      {:ok, commit_info} ->
        commit_info
      {:error, error} ->
        raise error
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
      {:error, error} ->
        raise error
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

  defp resolve_stats!(agent, revision) do
    with {:ok, branches} <- GitAgent.branches(agent),
         {:ok, tags} <- GitAgent.tags(agent),
         {:ok, commit_count} <- GitAgent.transaction(agent, {:history_count, revision.oid}, &resolve_history_count(&1, revision)) do
      %{
        branches: Enum.count(branches),
        tags: Enum.count(tags),
        commits: commit_count,
      }
    else
      {:error, error} ->
        raise error
    end
  end

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

  defp resolve_history_count(agent, revision) do
    case GitAgent.history(agent, revision, target: :commit_oid) do
      {:ok, stream} ->
        {:ok, Enum.count(stream)}
      {:error, reason} ->
        {:error, reason}
    end
  end
end
