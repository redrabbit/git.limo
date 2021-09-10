defmodule GitGud.Web.BranchSelectContainerLive do
  @moduledoc """
  Live view container for `GitGud.Web.BranchSelectLive`.
  """

  use GitGud.Web, :live_view

  alias GitRekt.GitAgent

  alias GitGud.RepoQuery

  import GitRekt.Git, only: [oid_parse: 1]

  @impl true
  def mount(_params, %{"repo_id" => repo_id, "rev_spec" => rev_spec, "action" => action, "tree_path" => tree_path} = session, socket) do
    {
      :ok,
      socket
      |> assign_new(:repo, fn -> RepoQuery.by_id(repo_id) end)
      |> assign_agent!()
      |> assign_revision!(rev_spec)
      |> assign_commit!()
      |> assign(active: connected?(socket) && !!session["active"], action: action, tree_path: tree_path)
    }
  end

  @impl true
  def render(assigns) do
    ~L"""
      <%= live_component(@socket, GitGud.Web.BranchSelectLive,
        id: "branch_select",
        repo: @repo,
        agent: @agent,
        revision: @revision,
        commit: @commit,
        tree_path: @tree_path,
        action: @action,
        active: @active
      ) %>
    """
  end

  #
  # Helpers
  #

  defp assign_agent!(socket) do
    assign_new(socket, :agent, fn -> resolve_agent!(socket.assigns.repo) end)
 end

  defp assign_revision!(socket, rev_spec) do
    assign_new(socket, :revision, fn -> resolve_revision!(socket.assigns.agent, rev_spec) end)
  end

  defp assign_commit!(socket) do
    assign_new(socket, :commit, fn -> resolve_commit!(socket.assigns.agent, socket.assigns.revision) end)
  end

  defp resolve_agent!(repo) do
    case GitAgent.unwrap(repo) do
      {:ok, agent} ->
        agent
      {:error, error} ->
        raise error
    end
  end

  defp resolve_revision!(agent, "branch:" <> branch_name) do
    case GitAgent.branch(agent, branch_name) do
      {:ok, tag} ->
        tag
      {:error, error} ->
        raise error
    end
  end

  defp resolve_revision!(agent, "tag:" <> tag_name) do
    case GitAgent.tag(agent, tag_name) do
      {:ok, tag} ->
        tag
      {:error, error} ->
        raise error
    end
  end

  defp resolve_revision!(agent, "commit:" <> commit_oid) do
    case GitAgent.object(agent, oid_parse(commit_oid)) do
      {:ok, commit} ->
        commit
      {:error, error} ->
        raise error
    end
  end

  defp resolve_commit!(agent, revision) do
    case GitAgent.peel(agent, revision, target: :commit) do
      {:ok, commit} ->
        commit
      {:error, error} ->
        raise error
    end
  end
end
