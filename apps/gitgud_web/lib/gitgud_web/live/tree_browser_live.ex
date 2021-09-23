defmodule GitGud.Web.TreeBrowserLive do
  @moduledoc """
  Live view responsible for rendering Git tree objects.
  """

  use GitGud.Web, :live_view

  alias GitRekt.GitRepo
  alias GitRekt.GitAgent

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
  def mount(%{"user_login" => user_login, "repo_name" => repo_name} = _params, session, socket) do
    {
      :ok,
      socket
      |> authenticate(session)
      |> assign(rev_spec: nil, revision: nil, commit: nil, stats: %{})
      |> assign_repo!(user_login, repo_name)
      |> assign_repo_open_issue_count()
      |> assign_agent!()
    }
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {
      :noreply,
      socket
      |> assign_tree!(params)
      |> assign_tree_commits_async()
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
    case GitRepo.get_agent(socket.assigns.repo) do
      {:ok, agent} ->
        assign(socket, :agent, agent)
      {:error, error} ->
        raise error
    end
  end

  defp assign_repo_open_issue_count(socket) do
    assign(socket, :repo_open_issue_count, GitGud.IssueQuery.count_repo_issues(socket.assigns.repo, status: :open))
  end

  defp assign_tree!(socket, params) do
    rev_spec = params["revision"]
    tree_path = params["path"] || []
    resolve_revision? = is_nil(socket.assigns.commit) or rev_spec != socket.assigns.rev_spec
    resolve_stats? = tree_path == [] and (resolve_revision? or socket.assigns.stats == %{})

    assigns =
      if resolve_stats?,
        do: resolve_revision_tree_with_stats!(socket.assigns.agent, resolve_revision? && rev_spec || socket.assigns.commit, tree_path),
      else: resolve_revision_tree!(socket.assigns.agent, resolve_revision? && rev_spec || socket.assigns.commit, tree_path)
    assigns = Map.update!(assigns, :tree_commit_info, &resolve_commit_info_db/1)
    assigns = Map.update!(assigns, :tree_entries, &Enum.sort_by(&1, fn tree_entry -> tree_entry.name end))
    assigns = Map.update!(assigns, :tree_entries, &Enum.map(&1, fn tree_entry -> {tree_entry, nil} end))
    assigns =
      if resolve_stats?,
        do: Map.update(assigns, :stats, %{}, &Map.put(&1, :contributors, RepoQuery.count_contributors(socket.assigns.repo))),
      else: assigns

    socket
    |> assign(rev_spec: rev_spec, tree_path: tree_path)
    |> assign(assigns)
  end

  defp assign_tree_commits_async(socket) do
    if connected?(socket) do
      send(self(), :assign_tree_commits)
    end
    socket
  end

  defp assign_tree_commits!(socket) when is_nil(socket.assigns.revision), do: socket
  defp assign_tree_commits!(socket) do
    {tree_commit_info, tree_entries} = resolve_tree_with_commits!(socket.assigns.agent, socket.assigns.commit, socket.assigns.tree_path)
    assign(socket, tree_commit_info: tree_commit_info, tree_entries: tree_entries)
  end

  defp assign_page_title(socket) do
    assign(socket, :page_title, GitGud.Web.CodebaseView.title(socket.assigns[:live_action], socket.assigns))
  end

  defp resolve_revision(agent, nil) do
    with {:ok, false} <- GitAgent.empty?(agent),
         {:ok, head} <- GitAgent.head(agent),
         {:ok, commit} <- GitAgent.peel(agent, head) do
      {:ok, {head, commit}}
    else
      {:ok, true} ->
        {:error, "repository is empty"}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp resolve_revision(agent, rev_spec) do
    with {:ok, {obj, ref}} <- GitAgent.revision(agent, rev_spec),
         {:ok, commit} <- GitAgent.peel(agent, obj, target: :commit) do
      {:ok, {ref, commit}}
    end
  end

  defp resolve_revision_tree!(agent, revision, tree_path) do
    case GitAgent.transaction(agent, &resolve_revision_tree(&1, revision, tree_path)) do
      {:ok, {ref, commit, commit_info, tree_entries, readme}} ->
        %{revision: ref || commit, commit: commit, tree_commit_info: commit_info, tree_entries: tree_entries, tree_readme: readme}
      {:ok, {commit_info, tree_entries, readme}} ->
        %{tree_commit_info: commit_info, tree_entries: tree_entries, tree_readme: readme}
      {:error, error} ->
        raise error
    end
  end

  defp resolve_revision_tree(agent, commit, tree_path) when is_struct(commit), do: resolve_tree(agent, commit, tree_path)
  defp resolve_revision_tree(agent, rev_spec, tree_path) do
    with {:ok, {ref, commit}} <- resolve_revision(agent, rev_spec),
         {:ok, {commit_info, tree_entries, readme}} <- resolve_tree(agent, commit, tree_path) do
      {:ok, {ref, commit, commit_info, tree_entries, readme}}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp resolve_revision_tree_with_stats!(agent, rev_spec, tree_path) do
    case GitAgent.transaction(agent, &resolve_revision_tree_with_stats(&1, rev_spec, tree_path)) do
      {:ok, {ref, commit, commit_info, tree_entries, readme, stats}} ->
        %{revision: ref || commit, commit: commit, tree_commit_info: commit_info, tree_entries: tree_entries, tree_readme: readme, stats: stats}
      {:ok, {commit_info, tree_entries, readme, stats}} ->
        %{tree_commit_info: commit_info, tree_entries: tree_entries, tree_readme: readme, stats: stats}
      {:error, error} ->
        raise error
    end
  end

  defp resolve_revision_tree_with_stats(agent, commit, tree_path) when is_struct(commit) do
    with {:ok, {commit_info, tree_entries, readme}} <- resolve_revision_tree(agent, commit, tree_path),
         {:ok, stats} <- resolve_stats(agent, commit) do
      {:ok, {commit_info, tree_entries, readme, stats}}
    end
  end

  defp resolve_revision_tree_with_stats(agent, rev_spec, tree_path) do
    with {:ok, {ref, commit, commit_info, tree_entries, readme}} <- resolve_revision_tree(agent, rev_spec, tree_path),
         {:ok, stats} <- resolve_stats(agent, commit) do
      {:ok, {ref, commit, commit_info, tree_entries, readme, stats}}
    end
  end

  defp resolve_tree(agent, commit, []) do
    with {:ok, commit_info} <- resolve_tree_commit_info(agent, commit),
         {:ok, tree_entries} <- GitAgent.tree_entries(agent, commit),
         {:ok, tree_readme} <- resolve_tree_readme(agent, tree_entries) do
      {:ok, {commit_info, Enum.to_list(tree_entries), tree_readme}}
    end
  end

  defp resolve_tree(agent, commit, tree_path) do
    with {:ok, tree_entries} <- GitAgent.tree_entries(agent, commit, path: Path.join(tree_path)),
         {:ok, tree_readme} <- resolve_tree_readme(agent, tree_entries) do
      {:ok, {nil, Enum.to_list(tree_entries), tree_readme}}
    end
  end

  defp resolve_tree_with_commits!(agent, commit, tree_path) do
    case GitAgent.transaction(agent, {:tree_entries_with_commit, commit.oid, tree_path}, &resolve_tree_with_commits(&1, commit, tree_path)) do
      {:ok, {commit_info, tree_entries}} ->
        {
          resolve_commit_info_db(commit_info),
          tree_entries
        }
      {:error, error} ->
        raise error
    end
  end

  defp resolve_tree_with_commits(agent, commit, []) do
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

  defp resolve_tree_with_commits(agent, commit, tree_path) do
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

  defp resolve_tree_readme(agent, tree_entries) do
    if tree_entry = Enum.find(tree_entries, &(&1.type == :blob && &1.name in ["README", "README.md"])) do
      with {:ok, blob} <- GitAgent.peel(agent, tree_entry),
           {:ok, blob_content} <- GitAgent.blob_content(agent, blob) do
        if String.ends_with?(tree_entry.name, ".md"),
          do: {:ok, {GitGud.Web.Markdown.markdown_safe(blob_content), tree_entry.name}},
        else: {:ok, {blob_content, tree_entry.name}}
      end
    else
      {:ok, nil}
    end
  end

  defp resolve_stats(agent, revision) do
    with {:ok, branch_count} <- GitAgent.transaction(agent, &resolve_branch_count/1),
         {:ok, tag_count} <- GitAgent.transaction(agent, &resolve_tag_count/1),
         {:ok, commit_count} <- GitAgent.transaction(agent, {:history_count, revision.oid}, &resolve_commit_count(&1, revision)) do
      {
        :ok,
        %{
          branches: branch_count,
          tags: tag_count,
          commits: commit_count,
        }
      }
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp resolve_commit_info_db(%{author: %{email: email}, committer: %{email: email}} = commit_info) do
      if user = UserQuery.by_email(email),
        do: %{commit_info|author: user, committer: user},
      else: commit_info
  end

  defp resolve_commit_info_db(%{author: author, committer: committer} = commit_info) do
    users = UserQuery.by_email([author.email, committer.email], preload: :emails)
    %{commit_info|author: resolve_user(author, users), committer: resolve_user(committer, users)}
  end

  defp resolve_commit_info_db(nil), do: nil

  defp resolve_user(%{email: email} = map, users) do
    Enum.find(users, map, fn user -> email in Enum.map(user.emails, &(&1.address)) end)
  end

  defp resolve_branch_count(agent) do
    case GitAgent.branches(agent, target: :commit_oid) do
      {:ok, stream} ->
        {:ok, Enum.count(stream)}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp resolve_tag_count(agent) do
    case GitAgent.tags(agent, target: :commit_oid) do
      {:ok, stream} ->
        {:ok, Enum.count(stream)}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp resolve_commit_count(agent, revision) do
    case GitAgent.history(agent, revision, target: :commit_oid) do
      {:ok, stream} ->
        {:ok, Enum.count(stream)}
      {:error, reason} ->
        {:error, reason}
    end
  end
end
