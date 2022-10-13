defmodule GitGud.Web.BranchSelectContainerLive do
  @moduledoc """
  Live view container for `GitGud.Web.BranchSelectLive`.
  """

  use GitGud.Web, :live_view

  alias GitRekt.GitRepo
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
      |> assign(active: connected?(socket) && !!session["active"], action: action, tree_path: tree_path)
    }
  end

  @impl true
  def render(assigns) do
    ~L"""
      <%= live_component(GitGud.Web.BranchSelectLive,
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
    if connected?(socket) do
      {revision, commit} = resolve_revision!(socket.assigns.agent, rev_spec)
      assign(socket, revision: revision, commit: commit)
    else
      {conn_assigns, _} = socket.private.assign_new
      assign(socket, Map.take(conn_assigns, [:revision, :commit]))
    end
  end

  defp resolve_agent!(repo) do
    case GitRepo.get_agent(repo) do
      {:ok, agent} ->
        agent
      {:error, error} ->
        raise error
    end
  end

  defp resolve_revision!(agent, "branch:" <> branch_name) do
    case GitAgent.branch(agent, branch_name, with: :commit) do
      {:ok, branch_with_commit} ->
        branch_with_commit
      {:error, error} ->
        raise error
    end
  end

  defp resolve_revision!(agent, "tag:" <> tag_name) do
    case GitAgent.tag(agent, tag_name, with: :commit) do
      {:ok, tag_with_commit} ->
        tag_with_commit
      {:error, error} ->
        raise error
    end
  end

  defp resolve_revision!(agent, "commit:" <> commit_oid) do
    case GitAgent.object(agent, oid_parse(commit_oid)) do
      {:ok, commit} ->
        {commit, commit}
      {:error, error} ->
        raise error
    end
  end
end
