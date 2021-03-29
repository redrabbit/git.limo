defmodule GitGud.Web.CommentLive do
  @moduledoc """
  Live component responsible for rendering comments.
  """

  use GitGud.Web, :live_component

  alias GitGud.Comment

  alias GitGud.UserQuery
  alias GitGud.IssueQuery

  @impl true
  def update(assigns, socket) do
    {
      :ok,
      socket
      |> assign(assigns)
      |> assign_changeset()
    }
  end

  @impl true
  def preload(list_of_assigns) do
    matches = parse_comments(list_of_assigns)
    repo = hd(list_of_assigns)[:repo]
    agent = hd(list_of_assigns)[:agent] || unwrap_agent!(repo)
    users = UserQuery.by_login(matches[:user_mentions] || [])
    issues = repo && IssueQuery.repo_issues(repo, numbers: matches[:issue_references] || []) || []
    Enum.map(list_of_assigns, fn assigns ->
      assigns
      |> Map.put_new(:agent, agent)
      |> Map.put(:comment_body_html, markdown_safe(assigns.comment.body, %{repo: repo, agent: agent, users: users, issues: issues}))
    end)
  end

  @impl true
  def handle_event("toggle_edit", _params, socket) when is_nil(socket.assigns.changeset) do
    {:noreply, assign(socket, :changeset, Comment.changeset(socket.assigns.comment))}
  end

  def handle_event("toggle_edit", _params, socket) do
    {:noreply, assign(socket, :changeset, nil)}
  end

  def handle_event("validate", %{"comment" => comment_params}, socket) do
    {:noreply, assign(socket, :changeset, Comment.changeset(socket.assigns.comment, comment_params))}
  end

  def handle_event("update", %{"comment" => comment_params}, socket) do
    case Comment.update(socket.assigns.comment, current_user(socket), comment_params) do
      {:ok, comment} ->
        send(self(), {:update_comment, comment})
        {:noreply, assign(socket, comment: comment, changeset: nil)}
      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("delete", _params, socket) do
    case Comment.delete(socket.assigns.comment) do
      {:ok, comment} ->
        send(self(), {:delete_comment, comment})
        {:noreply, assign(socket, :comment, comment)}
      {:error, changeset} ->
      {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  #
  # Helpers
  #

  defp assign_changeset(socket) when is_map_key(socket.assigns, :changeset), do: socket
  defp assign_changeset(socket), do: assign(socket, :changeset, nil)

  defp parse_comments(list_of_assigns) do
    Enum.map(
      Enum.reduce(list_of_assigns, %{}, fn assigns, acc ->
        Enum.reduce(GitGud.Web.Markdown.parse(assigns.comment.body), acc, fn {key, values}, acc ->
          Map.update(acc, key, [], &(&1 ++ values))
        end)
      end),
      fn {key, values} -> {key, Enum.uniq(values)} end
    )
  end

  defp unwrap_agent!(nil), do: nil
  defp unwrap_agent!(repo) do
    case GitRekt.GitAgent.unwrap(repo) do
      {:ok, agent} ->
        agent
      {:error, reason} ->
        raise reason
    end
  end
end
