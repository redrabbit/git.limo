defmodule GitGud.Web.BlobHeaderLive do
  @moduledoc """
  Live view responsible for rendering the latest Git commit of Git blob objects.
  """

  use GitGud.Web, :live_view

  alias GitRekt.GitAgent

  alias GitGud.UserQuery
  alias GitGud.RepoQuery

  import GitRekt.Git, only: [oid_fmt: 1, oid_parse: 1]

  import GitGud.Web.CodebaseView

  @impl true
  def mount(_params, %{"repo_id" => repo_id, "rev_spec" => rev_spec, "tree_path" => tree_path}, socket) do
    {
      :ok,
      socket
      |> assign_new(:repo, fn -> RepoQuery.by_id(repo_id) end)
      |> assign(rev_spec: rev_spec, tree_path: tree_path, blob_commit_info: nil)
      |> assign_blob_commit_async()
    }
  end

  @impl true
  def handle_info(:assign_blob_commit, socket) do
    {:noreply, assign_blob_commit!(socket)}
  end

  #
  # Helpers
  #

  defp assign_blob_commit!(socket) do
    assign(socket, :blob_commit_info, resolve_blob_commit_info!(socket.assigns.repo, socket.assigns.rev_spec, socket.assigns.tree_path))
  end

  defp assign_blob_commit_async(socket) do
    if connected?(socket) do
      send(self(), :assign_blob_commit)
    end
    socket
  end

  defp resolve_blob_commit_info!(repo, revision, tree_path) do
    case GitAgent.transaction(repo, &resolve_blob_commit_info(&1, revision, tree_path)) do
      {:ok, commit_info} ->
        resolve_commit_info_db(commit_info)
      {:error, error} ->
        raise error
    end
  end

  defp resolve_blob_commit_info(agent, "branch:" <> branch_name, tree_path) do
    with {:ok, branch} <- GitAgent.branch(agent, branch_name),
         {:ok, commit} <- GitAgent.peel(agent, branch) do
      GitAgent.transaction(agent, {:blob_commit, commit.oid, tree_path}, &resolve_blob_commit(&1, commit, tree_path))
    end
  end

  defp resolve_blob_commit_info(agent, "tag:" <> tag_name, tree_path) do
    with {:ok, tag} <- GitAgent.tag(agent, tag_name),
         {:ok, commit} <- GitAgent.peel(agent, tag) do
      GitAgent.transaction(agent, {:blob_commit, commit.oid, tree_path}, &resolve_blob_commit(&1, commit, tree_path))
    end
  end

  defp resolve_blob_commit_info(agent, "commit:" <> commit_oid, tree_path) do
    case GitAgent.object(agent, oid_parse(commit_oid)) do
      {:ok, commit} ->
        GitAgent.transaction(agent, {:blob_commit, commit.oid, tree_path}, &resolve_blob_commit(&1, commit, tree_path))
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp resolve_blob_commit(agent, commit, tree_path) do
    case GitAgent.tree_entry_by_path(agent, commit, Path.join(tree_path), with: :commit) do
      {:ok, {_tree_entries, commit}} ->
        resolve_commit_info(agent, commit)
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp resolve_commit_info(agent, commit) do
    with {:ok, message} <- GitAgent.commit_message(agent, commit),
         {:ok, timestamp} <- GitAgent.commit_timestamp(agent, commit),
         {:ok, author} <- GitAgent.commit_author(agent, commit),
         {:ok, committer} <- GitAgent.commit_committer(agent, commit), do:
      {:ok, %{oid: commit.oid, message: message, timestamp: timestamp, author: author, committer: committer}}
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

  defp resolve_user(%{email: email} = map, users) do
    Enum.find(users, map, fn user -> email in Enum.map(user.emails, &(&1.address)) end)
  end
end
