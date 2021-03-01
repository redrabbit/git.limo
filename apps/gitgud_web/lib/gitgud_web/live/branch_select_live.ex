defmodule GitGud.Web.BranchSelectLive do
  use GitGud.Web, :live_view

  alias GitRekt.Git
  alias GitRekt.GitAgent
  alias GitRekt.GitCommit
  alias GitRekt.GitRef
  alias GitRekt.GitTag

  alias GitGud.RepoQuery

  import GitGud.Web.CodebaseView, only: [
    revision_name: 1,
    revision_type: 1
  ]

  #
  # Callbacks
  #

  def mount(_params, %{"repo_id" => repo_id, "rev_spec" => rev_spec, "action" => action, "tree_path" => tree_path}, socket) do
    socket = assign_new(socket, :repo, fn -> RepoQuery.by_id(repo_id) end)
    socket = assign(socket, :agent, init_agent!(socket))
    socket = assign_new(socket, :revision, fn -> init_revision!(socket, rev_spec) end)
    socket = assign(socket,
      active: false,
      filter: "",
      tab: init_tab(socket),
      action: action,
      tree_path: tree_path
    )
    {:ok, socket}
  end

  def handle_event("toggle_dropdown", _value, socket) do
    unless Map.has_key?(socket.assigns, :refs),
      do: {:noreply, assign(socket, active: true, refs: init_references!(socket))},
    else: {:noreply, assign(socket, active: !socket.assigns.active)}
  end

  def handle_event("filter", %{"value" => filter}, socket) do
    {:noreply, assign(socket, :filter, filter)}
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :tab, String.to_atom(tab))}
  end

  #
  # Helpers
  #

  defp init_agent!(socket) when socket.connected? == false, do: nil
  defp init_agent!(socket) do
    case GitAgent.unwrap(socket.assigns.repo) do
      {:ok, agent} ->
        agent
      {:error, reason} ->
        raise RuntimeError, message: reason
    end
  end

  defp init_revision!(socket, "branch:" <> branch_name) do
    case GitAgent.branch(socket.assigns.agent, branch_name) do
      {:ok, tag} ->
        tag
      {:error, reason} ->
        raise RuntimeError, message: reason
    end
  end

  defp init_revision!(socket, "tag:" <> tag_name) do
    case GitAgent.tag(socket.assigns.agent, tag_name) do
      {:ok, tag} ->
        tag
      {:error, reason} ->
        raise RuntimeError, message: reason
    end
  end

  defp init_revision!(socket, "commit:" <> commit_oid) do
    case GitAgent.object(socket.assigns.agent, Git.oid_parse(commit_oid)) do
      {:ok, commit} ->
        commit
      {:error, reason} ->
        raise RuntimeError, message: reason
    end
  end

  defp init_references!(socket) do
    case GitAgent.references(socket.assigns.agent, with: :commit) do
      {:ok, refs} ->
        refs
        |> Enum.map(&map_reference_timestamp!(socket.assigns.agent, &1))
        |> Enum.sort_by(&elem(&1, 1), {:desc, NaiveDateTime})
        |> Enum.map(&elem(&1, 0))
        |> Enum.group_by(&(&1.type))
      {:error, reason} ->
        raise RuntimeError, message: reason
    end
  end

  defp init_tab(socket) do
    case socket.assigns.revision do
      %GitCommit{} ->
        :branch
      %GitTag{} ->
        :tag
      %GitRef{type: type} ->
        type
    end
  end

  defp map_reference_timestamp!(agent, {ref, commit}) do
    case GitAgent.commit_timestamp(agent, commit) do
      {:ok, timestamp} ->
        {ref, timestamp}
      {:error, reason} ->
        raise RuntimeError, message: reason
    end
  end
end
