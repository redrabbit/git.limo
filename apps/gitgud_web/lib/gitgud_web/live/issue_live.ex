defmodule GitGud.Web.IssueLive do
  @moduledoc """
  Live view responsible for rendering issues.
  """

  use GitGud.Web, :live_view

  alias GitGud.DB
  alias GitGud.DBQueryable

  alias GitGud.Issue
  alias GitGud.Comment

  alias GitGud.RepoQuery
  alias GitGud.IssueQuery

  def title_changeset(issue, params \\ %{}) do
    types = %{title: :string}
    data = %{title: issue.title}
    {data, types}
    |> Ecto.Changeset.cast(params, Map.keys(types))
    |> Ecto.Changeset.validate_required([:title])
  end

  #
  # Callbacks
  #

  @impl true
  def mount(%{"user_login" => user_login, "repo_name" => repo_name, "number" => number}, session, socket) do
    {
      :ok,
      socket
      |> authenticate(session)
      |> assign_repo!(user_login, repo_name)
      |> assign_repo_open_issue_count()
      |> assign_issue(String.to_integer(number))
      |> assign_title_changeset()
      |> assign(:title_edit, false),
      temporary_assigns: [issue_feed: []]
    }
  end

  @impl true
  def handle_event("update_title", %{"issue" => issue_params}, socket) do
    issue = Issue.update_title!(socket.assigns.issue, issue_params["title"], user_id: current_user(socket).id)
    {
      :noreply,
      socket
      |> assign(:issue, issue)
      |> assign(:issue_feed, [{List.last(issue.events), length(issue.events)}])
      |> assign(:title_edit, false)
    }
  end

  def handle_event("validate_title", %{"issue" => issue_params}, socket) do
    {:noreply, assign(socket, :title_changeset, title_changeset(socket.assigns.issue, issue_params))}
  end

  def handle_event("edit_title", _params, socket) do
    {:noreply, assign(socket, :title_edit, true)}
  end

  def handle_event("cancel_title_edit", _params, socket) do
    {:noreply, assign(socket, :title_edit, false)}
  end

  def handle_event("add_comment", %{"comment" => comment_params}, socket) do
    case Issue.add_comment(socket.assigns.issue, current_user(socket), comment_params["body"]) do
      {:ok, comment} ->
        send_update(GitGud.Web.CommentFormLive, id: "issue-comment-form", changeset: Comment.changeset(%Comment{}))
        {
          :noreply,
          socket
          |> assign(:issue_feed, [comment])
          |> push_event("add_comment", %{comment_id: comment.id})
        }
      {:error, changeset} ->
        send_update(GitGud.Web.CommentFormLive, id: "issue-comment-form", changeset: changeset)
        {:noreply, socket}
    end
  end

  def handle_event("validate_comment", %{"comment" => comment_params}, socket) do
    send_update(GitGud.Web.CommentFormLive, id: "issue-comment-form", changeset: Comment.changeset(%Comment{}, comment_params))
    {:noreply, socket}
  end

  def handle_event("close", _params, socket) do
    issue = Issue.close!(socket.assigns.issue, user_id: current_user(socket).id)
    {
      :noreply,
      socket
      |> assign(:issue, issue)
      |> assign(:issue_feed, [{List.last(issue.events), length(issue.events)}])
    }
  end

  def handle_event("reopen", _params, socket) do
    issue = Issue.reopen!(socket.assigns.issue, user_id: current_user(socket).id)
    {
      :noreply,
      socket
      |> assign(:issue, issue)
      |> assign(:issue_feed, [{List.last(issue.events), length(issue.events)}])
      |> push_event("add_event", %{event_id: length(issue.events)})
    }
  end

  @impl true
  def handle_info({:update_comment, comment_id}, socket) do
    {:noreply, push_event(socket, "update_comment", %{comment_id: comment_id})}
  end

  def handle_info({:delete_comment, comment_id}, socket) do
    {:noreply, push_event(socket, "delete_comment", %{comment_id: comment_id})}
  end

  def handle_info({:update_labels, changes}, socket) do
    issue = Issue.update_labels!(socket.assigns.issue, changes, user_id: current_user(socket).id)
    {
      :noreply,
      socket
      |> assign(:issue, issue)
      |> assign(:issue_feed, [{List.last(issue.events), length(issue.events)}])
    }
  end

  #
  # Helpers
  #

  defp assign_repo!(socket, user_login, repo_name) do
    query = DBQueryable.query({RepoQuery, :user_repo_query}, [user_login, repo_name], viewer: current_user(socket), preload: :issue_labels)
    assign(socket, :repo, DB.one!(query))
  end

  defp assign_repo_open_issue_count(socket) when socket.connected?, do: socket
  defp assign_repo_open_issue_count(socket) do
    assign(socket, :repo_open_issue_count, GitGud.IssueQuery.count_repo_issues(socket.assigns.repo, status: :open))
  end

  defp assign_issue(socket, %Issue{} = issue) do
    socket
    |> assign(:issue, issue)
    |> assign(:issue_feed, resolve_feed(issue))
    |> assign(:page_title, "#{issue.title} ##{issue.number} · #{socket.assigns.repo.owner.login}/#{socket.assigns.repo.name}")
  end

  defp assign_issue(socket, issue_number) do
    query = DBQueryable.query({IssueQuery, :repo_issue_query}, [socket.assigns.repo.id, issue_number], viewer: current_user(socket), preload: [:author, :labels])
    assign_issue(socket, DB.one!(query))
  end

  defp assign_title_changeset(socket) do
    assign(socket, :title_changeset, title_changeset(socket.assigns.issue))
  end

  defp resolve_feed(issue) do
    issue
    |> Ecto.assoc(:comments)
    |> DB.all()
    |> DB.preload(:author)
    |> Enum.concat(Enum.with_index(issue.events, 1))
    |> Enum.sort_by(&feed_sort_field/1, {:asc, NaiveDateTime})
  end

  defp feed_sort_field(%Comment{} = comment), do: comment.inserted_at
  defp feed_sort_field({event, _index}), do: NaiveDateTime.from_iso8601!(event["timestamp"])
end
