defmodule GitGud.Web.BranchSelectContainerLive do
  @moduledoc """
  Live view container for `GitGud.Web.BranchSelectLive`.
  """

  use GitGud.Web, :live_view

  alias GitRekt.GitAgent

  alias GitGud.DB
  alias GitGud.DBQueryable

  alias GitGud.RepoQuery

  import GitRekt.Git, only: [oid_parse: 1]

  @impl true
  def mount(_params, %{"repo_id" => repo_id, "rev_spec" => rev_spec, "action" => action, "tree_path" => tree_path}, socket) do
    {
      :ok,
      socket
      |> assign_repo!(repo_id)
      |> assign_agent!()
      |> assign_revision!(rev_spec)
      |> assign_commit!()
      |> assign(action: action, tree_path: tree_path)
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
        action: @action
      ) %>
    """
  end

  #
  # Helpers
  #

  defp assign_repo!(socket, repo_id) do
    assign_new(socket, :repo, fn ->
      DB.one!(DBQueryable.query({RepoQuery, :repo_query}, [repo_id]))
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

  defp assign_commit!(socket) do
    assign_new(socket, :commit, fn -> resolve_commit!(socket.assigns.agent, socket.assigns.revision) end)
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

  defp resolve_commit!(agent, revision) do
    case GitAgent.peel(agent, revision, target: :commit) do
      {:ok, commit} ->
        commit
      {:error, reason} ->
        raise RuntimeError, message: reason
    end
  end
end
