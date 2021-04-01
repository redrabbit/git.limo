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
    markdown_opts = []
    matches = parse_comments(list_of_assigns)
    repo = Enum.reduce_while(list_of_assigns, nil, &find_equal_assign(&1, &2, :repo))
    markdown_opts = repo && Keyword.put(markdown_opts, :repo, repo) || markdown_opts
    agent =  Enum.reduce_while(list_of_assigns, nil, &find_equal_assign(&1, &2, :agent))|| unwrap_agent!(repo)
    markdown_opts = agent && Keyword.put(markdown_opts, :agent, agent) || markdown_opts
    user_mentions = Keyword.get(matches, :user_mentions, [])
    users = length(user_mentions) > 0 && UserQuery.by_login(user_mentions) || []
    markdown_opts = Keyword.put(markdown_opts, :users, users)
    issue_references = Keyword.get(matches, :issue_references, [])
    issues = repo && length(issue_references) > 0 && IssueQuery.repo_issues(repo, numbers: issue_references) || []
    markdown_opts = Keyword.put(markdown_opts, :issues, issues)
    Enum.map(list_of_assigns, fn assigns ->
      assigns
      |> Map.put_new(:agent, agent)
      |> Map.put(:comment_body_html, markdown_safe(assigns.comment.body, markdown_opts))
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

  defp assign_changeset(socket) when is_map_key(socket.assigns, :changeset), do: socket
  defp assign_changeset(socket), do: assign(socket, :changeset, nil)

  defp find_equal_assign(assigns, acc, key) do
    case Map.fetch(assigns, key) do
      {:ok, ^acc} ->
        {:cont, acc}
      {:ok, val} when is_nil(acc) ->
        {:cont, val}
      {:ok, _val} ->
        {:halt, nil}
      :error ->
        {:halt, nil}
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
