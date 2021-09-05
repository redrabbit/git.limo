defmodule GitGud.Web.CommentLive do
  @moduledoc """
  Live component responsible for rendering comments.
  """

  use GitGud.Web, :live_component

  alias GitGud.Comment

  alias GitGud.UserQuery
  alias GitGud.RepoQuery
  alias GitGud.IssueQuery
  alias GitGud.CommentQuery

  @impl true
  def preload(list_of_assigns) do
    case list_of_assigns do
      [assigns|_tail] when is_map_key(assigns, :current_user) ->
        current_user = Map.fetch!(assigns, :current_user)
        repo = Map.get_lazy(assigns, :repo, fn -> RepoQuery.by_id(assigns.comment.repo_id) end)
        repo_permissions = Map.get_lazy(assigns, :repo_permissions, fn -> RepoQuery.permissions(repo, current_user) end)
        agent = Map.get_lazy(assigns, :agent, fn -> unwrap_agent!(repo) end)
        matches = parse_comments(list_of_assigns)
        user_mentions = Keyword.get(matches, :user_mentions, [])
        issue_references = Keyword.get(matches, :issue_references, [])
        markdown_opts = [
          repo: repo,
          agent: agent,
          users: length(user_mentions) > 0 && UserQuery.by_login(user_mentions) || [],
          issues: length(issue_references) > 0 && IssueQuery.repo_issues(repo, numbers: issue_references) || []
        ]

        Enum.map(list_of_assigns, fn assigns ->
          assigns
          |> Map.put_new_lazy(:permissions, fn -> CommentQuery.permissions(assigns.comment, current_user, repo_permissions) end)
          |> Map.put_new(:agent, agent)
          |> Map.put_new_lazy(:comment_body_html, fn -> markdown_safe(assigns.comment.body, markdown_opts) end)
        end)
      list_of_assigns ->
        list_of_assigns
    end
  end

  @impl true
  def mount(socket) do
    {:ok, assign(socket, :comment_body_html, nil)}
  end

  @impl true
  def update(assigns, socket) do
    {
      :ok,
      socket
      |> assign(assigns)
      |> assign_body_html(assigns)
      |> assign_changeset()
    }
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
        send(self(), {:update_comment, comment.id})
        {
          :noreply,
          socket
          |> assign(:comment, comment)
          |> assign(:comment_body_html, markdown_safe(comment.body, Map.take(socket.assigns, [:repo, :agent])))
          |> assign(changeset: nil)}
      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("delete", _params, socket) do
    case Comment.delete(socket.assigns.comment) do
      {:ok, comment} ->
        send(self(), {:delete_comment, comment.id})
        {:noreply, assign(socket, :comment, comment)}
      {:error, changeset} ->
      {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  #
  # Helpers
  #

  defp assign_body_html(socket, assigns) when not is_nil(assigns.comment_body_html), do: socket
  defp assign_body_html(socket, assigns) do
    assign(socket, :comment_body_html, markdown_safe(assigns.comment.body, repo: socket.assigns.repo, agent: socket.assigns.agent))
  end

  defp assign_changeset(socket) when is_map_key(socket.assigns, :changeset), do: socket
  defp assign_changeset(socket), do: assign(socket, :changeset, nil)

  defp unwrap_agent!(nil), do: nil
  defp unwrap_agent!(repo) do
    case GitRekt.GitAgent.unwrap(repo) do
      {:ok, agent} ->
        agent
      {:error, reason} ->
        raise reason
    end
  end

  defp parse_comments(list_of_assigns) do
    Enum.map(
      Enum.reduce(list_of_assigns, %{}, fn assigns, acc ->
        Enum.reduce(GitGud.Web.Markdown.parse(assigns.comment.body), acc, fn {key, values}, acc ->
          Map.update(acc, key, values, &(&1 ++ values))
        end)
      end),
      fn {key, values} -> {key, Enum.uniq(values)} end
    )
  end
end
