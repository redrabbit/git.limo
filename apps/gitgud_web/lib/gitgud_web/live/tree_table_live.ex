defmodule GitGud.Web.TreeTableLive do
  use GitGud.Web, :live_view

  alias GitRekt.GitAgent

  alias GitGud.UserQuery
  alias GitGud.RepoQuery

  import GitGud.Web.CodebaseView

  #
  # Callbacks
  #

  @impl true
  def mount(_params, %{"repo_id" => repo_id, "revision" => revision, "tree_path" => tree_path}, socket) do
    {
      :ok,
      socket
      |> assign(:tree_path, tree_path)
      |> assign_new(:repo, fn -> RepoQuery.by_id(repo_id) end)
      |> assign_agent!()
      |> assign_revision!(revision)
      |> assign_tree!(tree_path)
    }
  end

  #
  # Helpers
  #

  defp assign_agent!(socket) when socket.connected? == false, do: socket
  defp assign_agent!(socket) do
    case GitAgent.unwrap(socket.assigns.repo) do
      {:ok, agent} ->
        assign(socket, :agent, agent)
      {:error, reason} ->
        raise RuntimeError, message: reason
    end
  end

  defp assign_revision!(socket, revision) do
    if connected?(socket) do
      case GitAgent.revision(socket.assigns.agent, revision) do
        {:ok, {commit, nil}} ->
          assign(socket, revision: commit, commit: commit)
        {:ok, {commit, reference}} ->
          assign(socket, revision: reference, commit: commit)
        {:error, reason} ->
          raise RuntimeError, message: reason
      end
    else
      {conn_assigns, _sock_assigns} = socket.private.assign_new
      assign(socket, revision: conn_assigns.revision, commit: conn_assigns.commit)
    end
  end

  defp assign_tree!(socket, tree_path) do
    if connected?(socket) do
      {commit_info, tree_entries} = resolve_tree!(socket.assigns.agent, socket.assigns.commit, tree_path)
      assign(socket, commit_info: commit_info, tree_entries: tree_entries)
    else
      {conn_assigns, _sock_assigns} = socket.private.assign_new
      assign(socket, commit_info: conn_assigns[:commit_info], tree_entries: conn_assigns.tree_entries)
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
end
