defmodule GitGud.Web.TreeBrowserLive do
  use GitGud.Web, :live_view

  alias GitRekt.GitAgent
  alias GitRekt.GitRef
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
      |> assign_repo!(user_login, repo_name)
      |> assign_repo_open_issue_count!()
      |> assign_agent!()
      |> assign_revision!(params["revision"])
    }
  end

  @impl true
  def handle_params(params, _uri, socket) do
    revision = socket.assigns.revision_spec
    case params["revision"] do
      ^revision ->
        {
          :noreply,
          socket
          |> assign(tree_path: params["path"] || [])
          |> assign_tree!()
          |> assign_stats!()
          |> assign_page_title()
        }
      nil ->
        {:noreply, redirect(socket, to: Routes.codebase_path(socket, :show, socket.assigns.repo.owner, socket.assigns.repo))}
      revision ->
        {:noreply, redirect(socket, to: Routes.codebase_path(socket, :tree, socket.assigns.repo.owner, socket.assigns.repo, revision, socket.assigns.tree_path))}
    end
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
      {:error, reason} ->
        raise RuntimeError, message: reason
    end
  end

  defp assign_repo_open_issue_count!(socket) when socket.connected?, do: socket
  defp assign_repo_open_issue_count!(socket) do
    assign(socket, :repo_open_issue_count, GitGud.IssueQuery.count_repo_issues(socket.assigns.repo, status: :open))
  end

  defp assign_revision!(socket, nil) do
    with {:ok, head} <- GitAgent.head(socket.assigns.agent),
         {:ok, commit} <- GitAgent.peel(socket.assigns.agent, head) do
      assign(socket, revision_spec: nil, revision: head, commit: commit)
    else
      {:error, reason} ->
        raise RuntimeError, message: reason
    end
  end

  defp assign_revision!(socket, rev_spec) do
    with {:ok, {obj, ref}} <- GitAgent.revision(socket.assigns.agent, rev_spec),
         {:ok, commit} <- GitAgent.peel(socket.assigns.agent, obj, target: :commit) do
      assign(socket, revision_spec: rev_spec, revision: ref || commit, commit: commit)
    else
      {:error, reason} ->
        raise RuntimeError, message: reason
    end
  end

  defp assign_tree!(socket) do
    commit_info = if Enum.empty?(socket.assigns.tree_path), do: resolve_tree_commit_info!(socket.assigns.agent, socket.assigns.commit)
    tree_entries = resolve_tree_entries!(socket.assigns.agent, socket.assigns.commit, socket.assigns.tree_path)
    tree_readme = Enum.find_value(tree_entries, &resolve_tree_readme!(socket.assigns.agent, &1))
    send(self(), :assign_tree_commits)
    assign(socket, commit_info: commit_info, tree_entries: tree_entries, tree_readme: tree_readme)
  end

  defp assign_tree_commits!(socket) do
    {commit_info, tree_entries} = resolve_tree!(socket.assigns.agent, socket.assigns.commit, socket.assigns.tree_path)
    assign(socket, commit_info: commit_info, tree_entries: tree_entries)
  end

  defp assign_stats!(socket) when socket.assigns.stats or socket.assigns.tree_path != [], do: socket
  defp assign_stats!(socket) when is_struct(socket.assigns.repo.stats, Ecto.Association.NotLoaded) do
    socket
    |> assign(:repo, DB.preload(socket.assigns.repo, :stats))
    |> assign_stats!()
  end

  defp assign_stats!(socket) do
    assign(socket, :stats, resolve_stats!(socket.assigns.repo, socket.assigns.agent, socket.assigns.revision))
  end

  defp assign_page_title(socket) do
    assign(socket, :page_title, GitGud.Web.CodebaseView.title(socket.assigns[:live_action], socket.assigns))
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

  defp resolve_stats!(repo, agent, revision) do
    ref_groups = Enum.group_by(repo.stats.refs, fn {"refs/" <> ref_name_suffix, _stats} -> hd(Path.split(ref_name_suffix)) end)
    %{
      commits: resolve_stats_revision_history_count!(agent, revision, repo.stats.refs),
      branches: Enum.count(Map.get(ref_groups, "heads", [])),
      tags: Enum.count(Map.get(ref_groups, "tags", [])),
      contributors: RepoQuery.count_contributors(repo)
    }
  end

  defp resolve_stats_revision_history_count!(_agent, %GitRef{} = revision, refs) do
    get_in(refs, [to_string(revision), "count"]) || raise RuntimeError, message: "cannot retrieve number of ancestors for #{revision}"
  end

  defp resolve_stats_revision_history_count!(agent, revision, _refs) do
    case GitAgent.history_count(agent, revision) do
      {:ok, commit_count} ->
        commit_count
      {:error, reason} ->
        raise RuntimeError, message: reason
    end
  end
end
