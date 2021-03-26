defmodule GitGud.Web.BlobHeaderLive do
  use GitGud.Web, :live_view

  alias GitRekt.GitAgent

  alias GitGud.DB
  alias GitGud.DBQueryable

  alias GitGud.RepoQuery

  import GitRekt.Git, only: [oid_fmt: 1, oid_parse: 1]

  import GitGud.Web.CodebaseView

  @impl true
  def mount(_params, %{"repo_id" => repo_id, "rev_spec" => rev_spec, "tree_path" => tree_path} = session, socket) do
    if connected?(socket) do
      {
        :ok,
        socket
        |> authenticate(session)
        |> assign_repo!(repo_id)
        |> assign_agent!()
        |> assign_revision!(rev_spec)
        |> assign(tree_path: tree_path, blob_commit_info: nil)
        |> assign_blob_commit_async()
      }
    else
      {
        :ok,
        socket
        |> authenticate(session)
        |> assign_repo!(repo_id)
        |> assign(tree_path: tree_path, blob_commit_info: nil)
      }
    end
  end

  @impl true
  def handle_info(:assign_blob_commit, socket) do
    {:noreply, assign_blob_commit!(socket)}
  end

  #
  # Helpers
  #

  defp assign_repo!(socket, repo_id) do
    assign_new(socket, :repo, fn ->
      DB.one!(DBQueryable.query({RepoQuery, :repo_query}, [repo_id], viewer: current_user(socket)))
    end)
  end

  defp assign_agent!(socket) do
    case GitAgent.unwrap(socket.assigns.repo) do
      {:ok, agent} ->
        assign(socket, :agent, agent)
      {:error, reason} ->
        raise RuntimeError, message: reason
    end
 end

  defp assign_revision!(socket, rev_spec) do
    assign_new(socket, :revision, fn -> resolve_revision!(socket.assigns.agent, rev_spec) end)
  end

  defp assign_blob_commit!(socket) do
    assign(socket, :blob_commit_info, resolve_blob_commit!(socket.assigns.agent, socket.assigns.revision, socket.assigns.tree_path))
  end

  defp assign_blob_commit_async(socket) when not socket.connected?, do: socket
  defp assign_blob_commit_async(socket) when socket.connected? do
    send(self(), :assign_blob_commit) && socket
  end

  defp resolve_revision!(agent, "branch:" <> branch_name) do
    case GitAgent.branch(agent, branch_name) do
      {:ok, tag} ->
        tag
      {:error, reason} ->
        raise RuntimeError, message: reason
    end
  end

  defp resolve_revision!(agent, "tag:" <> tag_name) do
    case GitAgent.tag(agent, tag_name) do
      {:ok, tag} ->
        tag
      {:error, reason} ->
        raise RuntimeError, message: reason
    end
  end

  defp resolve_revision!(agent, "commit:" <> commit_oid) do
    case GitAgent.object(agent, oid_parse(commit_oid)) do
      {:ok, commit} ->
        commit
      {:error, reason} ->
        raise RuntimeError, message: reason
    end
  end

  defp resolve_blob_commit!(agent, revision, tree_path) do
    case GitAgent.tree_entry_by_path(agent, revision, Path.join(tree_path), with: :commit) do
      {:ok, {_tree_entries, commit}} ->
        resolve_blob_commit_info!(agent, commit)
      {:error, reason} ->
        raise RuntimeError, message: reason
    end
  end

  defp resolve_blob_commit_info!(agent, commit) do
    case GitAgent.transaction(agent, &resolve_blob_commit_info(&1, commit)) do
      {:ok, commit_info} ->
        commit_info
      {:error, reason} ->
        raise RuntimeError, message: reason
    end
  end

  defp resolve_blob_commit_info(agent, commit) do
    with {:ok, message} <- GitAgent.commit_message(agent, commit),
         {:ok, timestamp} <- GitAgent.commit_timestamp(agent, commit),
         {:ok, author} <- GitAgent.commit_author(agent, commit),
         {:ok, committer} <- GitAgent.commit_committer(agent, commit), do:
      {:ok, %{oid: commit.oid, message: message, timestamp: timestamp, author: author, committer: committer}}
  end
end
