defmodule GitGud.Web.BlobViewerLive do
  @moduledoc """
  Live view responsible for rendering Git blob objects.
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
  def mount(%{"user_login" => user_login, "repo_name" => repo_name} = params, session, socket) do
    span =
      "live_view"
      |> Appsignal.Tracer.create_span(Appsignal.Tracer.current_span())
      |> Appsignal.Span.set_name("GitGud.Web.BlobViewerLive#mount")
      |> Appsignal.Span.set_attribute("appsignal:category", "call.live_view")
      |> Appsignal.Span.set_sample_data("environment", Appsignal.Metadata.metadata(socket))
      |> Appsignal.Span.set_sample_data("params", params)
      |> Appsignal.Span.set_sample_data("session_data", session)
    result =
      Appsignal.instrument("GitGud.Web.BlobViewerLive", "mount.live_view", fn ->
        {
          :ok,
          socket
          |> authenticate(session)
          |> assign(rev_spec: nil, revision: nil, commit: nil, blob_commit_info: nil)
          |> assign(:blob_path, Map.fetch!(params, "path"))
          |> assign_repo!(user_login, repo_name)
          |> assign_repo_open_issue_count()
          |> assign_agent!()
          |> assign_blob!(params)
          |> assign_page_title()
          |> assign_blob_commit_async()
        }
      end)
    unless connected?(socket), do: Appsignal.Tracer.close_span(span)
    result
  end

  @impl true
  def handle_info(:assign_blob_commit, socket) do
    socket = Appsignal.instrument("GitGud.Web.BlobViewerLive", "handle_info.live_view", fn -> assign_blob_commit!(socket) end)
    Appsignal.Tracer.close_span(Appsignal.Tracer.current_span())
    {:noreply, socket}
  end

  #
  # Helpers
  #

  defp assign_repo!(socket, user_login, repo_name) do
    query = DBQueryable.query({RepoQuery, :user_repo_query}, [user_login, repo_name], viewer: current_user(socket))
    assign(socket, :repo, DB.one!(query))
  end

  defp assign_repo_open_issue_count(socket) do
    assign(socket, :repo_open_issue_count, GitGud.IssueQuery.count_repo_issues(socket.assigns.repo, status: :open))
  end

  defp assign_agent!(socket) do
    case GitRepo.get_agent(socket.assigns.repo) do
      {:ok, agent} ->
        assign(socket, :agent, agent)
      {:error, error} ->
        raise error
    end
  end

  defp assign_blob!(socket, params) do
    assign(socket, resolve_revision_blob!(socket.assigns.agent, params["revision"], params["path"]))
  end

  defp assign_blob_commit!(socket) do
    assign(socket, :blob_commit_info, resolve_blob_commit_info!(socket.assigns.repo, socket.assigns.commit, socket.assigns.blob_path))
  end

  defp assign_blob_commit_async(socket) do
    if connected?(socket) do
      send(self(), :assign_blob_commit)
    end
    socket
  end

  defp assign_page_title(socket) do
    assign(socket, :page_title, GitGud.Web.CodebaseView.title(socket.assigns[:live_action], socket.assigns))
  end

  defp resolve_revision_blob!(agent, revision, blob_path) do
    case GitAgent.transaction(agent, &resolve_revision_blob(&1, revision, blob_path)) do
      {:ok, {ref, commit, blob_content, blob_size}} ->
        %{revision: ref || commit, commit: commit, blob_content: blob_content, blob_size: blob_size}
      {:error, error} ->
        raise error
    end
  end

  defp resolve_revision_blob(agent, rev_spec, blob_path) do
    with {:ok, {object, ref}} <- GitAgent.revision(agent, rev_spec),
         {:ok, commit} <- GitAgent.peel(agent, object, target: :commit),
         {:ok, tree_entry} <- GitAgent.tree_entry_by_path(agent, commit, Path.join(blob_path)),
         {:ok, blob} <- GitAgent.peel(agent, tree_entry),
         {:ok, blob_content} <- GitAgent.blob_content(agent, blob),
         {:ok, blob_size} <- GitAgent.blob_size(agent, blob) do
      {:ok, {ref, commit, blob_content, blob_size}}
    end
  end

  defp resolve_blob_commit_info!(repo, revision, tree_path) do
    case GitAgent.transaction(repo, &resolve_blob_commit(&1, revision, tree_path)) do
      {:ok, commit_info} ->
        resolve_commit_info_db(commit_info)
      {:error, error} ->
        raise error
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
