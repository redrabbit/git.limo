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
  alias GitGud.CommentQuery

  alias GitGud.Web.Presence

  import GitGud.Web.Endpoint, only: [broadcast_from: 4, subscribe: 1]

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
      |> assign_repo_permissions()
      |> assign_repo_open_issue_count()
      |> assign_issue(String.to_integer(number))
      |> assign_page_title()
      |> assign_title_changeset()
      |> assign_presence!()
      |> assign_presence_map()
      |> assign_users_typing()
      |> subscribe_topic!(),
      temporary_assigns: [issue_feed: []]
    }
  end

  @impl true
  def handle_event("update_title", %{"issue" => issue_params}, socket) do
    changeset = title_changeset(socket.assigns.issue, issue_params)
    case Ecto.Changeset.apply_action(changeset, :update) do
      {:ok, data} ->
        issue = Issue.update_title!(socket.assigns.issue, data.title, user_id: current_user(socket).id)
        event = List.last(issue.events)
        broadcast_from(self(), issue_topic(socket), "update_title", %{title: issue.title, event: event})
        {
          :noreply,
          socket
          |> assign(:issue, issue)
          |> assign(:issue_feed, [{Map.put(event, "user", current_user(socket)), length(issue.events)}])
          |> assign_page_title()
          |> assign(:title_edit, false)
          |> assign(:title_changeset, title_changeset(issue))
        }
      {:error, changeset} ->
        {:noreply, assign(socket, :title_changeset, changeset)}
    end
  end

  def handle_event("validate_title", %{"issue" => issue_params}, socket) do
    {:noreply, assign(socket, :title_changeset, title_changeset(socket.assigns.issue, issue_params))}
  end

  def handle_event("edit_title", _params, socket) do
    {:noreply, assign(socket, :title_edit, true)}
  end

  def handle_event("cancel_title_edit", _params, socket) do
    {:noreply, assign(socket, title_edit: false, title_changeset: title_changeset(socket.assigns.issue))}
  end

  def handle_event("add_comment", %{"comment" => comment_params}, socket) do
    case Issue.add_comment(socket.assigns.issue, current_user(socket), comment_params["body"]) do
      {:ok, comment} ->
        send_update(GitGud.Web.CommentFormLive, id: "issue-comment-form", changeset: Comment.changeset(%Comment{}))
        broadcast_from(self(), issue_topic(socket), "add_comment", %{comment_id: comment.id})
        {
          :noreply,
          socket
          |> assign(:issue_comment_count, socket.assigns.issue_comment_count + 1)
          |> assign(:issue_feed, [comment])
          |> assign_presence_typing!(false)
          |> push_event("add_comment", %{comment_id: comment.id})
        }
      {:error, changeset} ->
        send_update(GitGud.Web.CommentFormLive, id: "issue-comment-form", changeset: changeset)
        {:noreply, assign_presence_typing!(socket, false)}
    end
  end

  def handle_event("validate_comment", %{"comment" => comment_params}, socket) do
    changeset = Comment.changeset(%Comment{}, comment_params)
    send_update(GitGud.Web.CommentFormLive, id: "issue-comment-form", changeset: changeset)
    {:noreply, assign_presence_typing!(socket, !!Ecto.Changeset.get_change(changeset, :body))}
  end

  def handle_event("close", _params, socket) do
    issue = Issue.close!(socket.assigns.issue, user_id: current_user(socket).id)
    event = List.last(issue.events)
    broadcast_from(self(), issue_topic(socket), "close", %{event: event})
    {
      :noreply,
      socket
      |> assign(:issue, issue)
      |> assign(:issue_feed, [{Map.put(event, "user", current_user(socket)), length(issue.events)}])
    }
  end

  def handle_event("reopen", _params, socket) do
    issue = Issue.reopen!(socket.assigns.issue, user_id: current_user(socket).id)
    event = List.last(issue.events)
    broadcast_from(self(), issue_topic(socket), "reopen", %{event: event})
    {
      :noreply,
      socket
      |> assign(:issue, issue)
      |> assign(:issue_feed, [{Map.put(event, "user", current_user(socket)), length(issue.events)}])
    }
  end

  @impl true
  def handle_info({:update_labels, {push_ids, pull_ids} = changes}, socket) do
    issue = Issue.update_labels!(socket.assigns.issue, changes, user_id: current_user(socket).id)
    event = List.last(issue.events)
    broadcast_from(self(), issue_topic(socket), "update_labels", %{push_ids: push_ids, pull_ids: pull_ids, event: event})
    {
      :noreply,
      socket
      |> assign(:issue, issue)
      |> assign(:issue_feed, [{Map.put(event, "user", current_user(socket)), length(issue.events)}])
    }
  end

  def handle_info({:update_comment, comment_id}, socket) do
    broadcast_from(self(), issue_topic(socket), "update_comment", %{comment_id: comment_id})
    {:noreply, push_event(socket, "update_comment", %{comment_id: comment_id})}
  end

  def handle_info({:delete_comment, comment_id}, socket) do
    broadcast_from(self(), issue_topic(socket), "delete_comment", %{comment_id: comment_id})
    {
      :noreply,
      socket
      |> assign(:issue_comment_count, socket.assigns.issue_comment_count - 1)
      |> push_event("delete_comment", %{comment_id: comment_id})
    }
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "update_title", payload: %{title: title, event: event}}, socket) do
    issue = socket.assigns.issue
    issue = struct(issue, title: title, events: List.insert_at(issue.events, -1, event))
    {
      :noreply,
      socket
      |> assign(:issue, issue)
      |> assign(:issue_feed, [{event, length(issue.events)}])
      |> assign(:title_changeset, title_changeset(issue))
      |> assign_page_title()
    }
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "close", payload: %{event: event}}, socket) do
    issue = socket.assigns.issue
    issue = struct(issue, status: "close", events: List.insert_at(issue.events, -1, event))
    {
      :noreply,
      socket
      |> assign(:issue, issue)
      |> assign(:issue_feed, [{event, length(issue.events)}])
    }
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "reopen", payload: %{event: event}}, socket) do
    issue = socket.assigns.issue
    issue = struct(issue, status: "open", events: List.insert_at(issue.events, -1, event))
    {
      :noreply,
      socket
      |> assign(:issue, issue)
      |> assign(:issue_feed, [{event, length(issue.events)}])
    }
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "update_labels", payload: %{push_ids: push_ids, pull_ids: pull_ids, event: event}}, socket) do
    issue = socket.assigns.issue
    issue_labels = Enum.concat(Enum.reject(issue.labels, &(&1.id in pull_ids)), Enum.filter(socket.assigns.repo.issue_labels, &(&1.id in push_ids)))
    issue = struct(issue, labels: issue_labels, events: List.insert_at(issue.events, -1, event))

    {
      :noreply,
      socket
      |> assign(:issue, issue)
      |> assign(:issue_feed, [{event, length(issue.events)}])
    }
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "commit_reference", payload: %{event: event}}, socket) do
    issue = socket.assigns.issue
    issue = struct(issue, events: List.insert_at(issue.events, -1, event))
    {
      :noreply,
      socket
      |> assign(:issue, issue)
      |> assign(:issue_feed, [{event, length(issue.events)}])
    }
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "add_comment", payload: %{comment_id: comment_id}}, socket) do
    comment = CommentQuery.by_id(comment_id, preload: :author)
    {
      :noreply,
      socket
      |> assign(:issue_comment_count, socket.assigns.issue_comment_count + 1)
      |> assign(:issue_feed, [comment])
      |> push_event("add_comment", %{comment_id: comment.id})
    }
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "update_comment", payload: %{comment_id: comment_id}}, socket) do
    comment = CommentQuery.by_id(comment_id, preload: :author)
    send_update(GitGud.Web.CommentLive, id: "comment-#{comment_id}", comment: comment)
    {:noreply, push_event(socket, "update_comment", %{comment_id: comment_id})}
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "delete_comment", payload: %{comment_id: comment_id}}, socket) do
    {
      :noreply,
      socket
      |> assign(:issue_comment_count, socket.assigns.issue_comment_count - 1)
      |> push_event("delete_comment", %{comment_id: comment_id})
    }
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", payload: %{joins: joins, leaves: leaves}}, socket) do
    {
      :noreply,
      socket
      |> assign_presence_map(joins, leaves)
      |> assign_users_typing()
    }
  end

  #
  # Helpers
  #

  defp assign_repo!(socket, user_login, repo_name) do
    query = DBQueryable.query({RepoQuery, :user_repo_query}, [user_login, repo_name], viewer: current_user(socket), preload: :issue_labels)
    assign(socket, :repo, DB.one!(query))
  end

  defp assign_repo_permissions(socket) do
    if connected?(socket),
      do: assign(socket, :repo_permissions, RepoQuery.permissions(socket.assigns.repo, current_user(socket))),
    else: assign(socket, :repo_permissions, [])
  end

  defp assign_repo_open_issue_count(socket) do
    assign(socket, :repo_open_issue_count, IssueQuery.count_repo_issues(socket.assigns.repo, status: :open))
  end

  defp assign_issue(socket, %Issue{} = issue) do
    feed = resolve_feed(issue)
    socket
    |> assign(:issue, issue)
    |> assign_issue_permissions()
    |> assign(:issue_comment, issue.comment)
    |> assign(:issue_comment_count, Enum.count(Enum.filter(feed, &is_struct(&1, Comment))))
    |> assign(:issue_feed, feed)
  end

  defp assign_issue(socket, issue_number) do
    query = DBQueryable.query({IssueQuery, :repo_issue_query}, [socket.assigns.repo.id, issue_number], viewer: current_user(socket), preload: [:author, {:comment, :author}, :labels])
    assign_issue(socket, DB.one!(query))
  end

  defp assign_issue_permissions(socket) do
    if connected?(socket),
      do: assign(socket, :issue_permissions, IssueQuery.permissions(socket.assigns.issue, current_user(socket), socket.assigns.repo_permissions)),
    else: assign(socket, :issue_permissions, [])
  end

  defp assign_page_title(socket) do
    assign(socket, :page_title, "#{socket.assigns.issue.title} ##{socket.assigns.issue.number} · #{socket.assigns.repo.owner_login}/#{socket.assigns.repo.name}")
  end

  defp assign_title_changeset(socket) do
    assign(socket, title_changeset: title_changeset(socket.assigns.issue), title_edit: false)
  end

  defp assign_presence!(socket) do
    if connected?(socket) && verified?(socket) do
      {:ok, presence_ref} = Presence.track(self(), issue_topic(socket), current_user(socket).login, %{typing: false})
      assign(socket, presence_ref: presence_ref, presence_typing: false)
    else
      assign(socket, presence_ref: nil, presence_typing: false)
    end
  end

  defp assign_presence_map(socket) do
    assign(socket, :presence_map, Presence.list(issue_topic(socket)))
  end

  defp assign_presence_map(socket, joins, leaves) do
    presences = socket.assigns.presence_map
    presences = Enum.reduce(leaves, presences, fn {key, _presence}, acc -> Map.delete(acc, key) end)
    presences = Enum.reduce(joins, presences, fn {key, presence}, acc -> Map.put(acc, key, presence) end)
    assign(socket, :presence_map, presences)
  end

  defp assign_presence_typing!(socket, presence_typing) do
    if socket.assigns.presence_typing != presence_typing do
      {:ok, presence_ref} = Presence.update(self(), issue_topic(socket), current_user(socket).login, &Map.put(&1, :typing, presence_typing))
      assign(socket, presence_ref: presence_ref, presence_typing: presence_typing)
    else
      socket
    end
  end

  defp assign_users_typing(socket) do
    assign(socket, :users_typing, Enum.flat_map(socket.assigns.presence_map, &filter_map_presence_to_user_typing(&1, socket.assigns.presence_ref)))
  end

  defp resolve_feed(issue) do
    issue
    |> Ecto.assoc(:replies)
    |> DB.all()
    |> DB.preload(:author)
    |> Enum.concat(Enum.with_index(issue.events, 1))
    |> Enum.sort_by(&feed_sort_field/1, {:asc, NaiveDateTime})
  end

  defp feed_sort_field(%Comment{} = comment), do: comment.inserted_at
  defp feed_sort_field({event, _index}), do: NaiveDateTime.from_iso8601!(event["timestamp"])

  defp title_changeset(issue, params \\ %{}) do
    types = %{title: :string}
    data = %{title: issue.title}
    {data, types}
    |> Ecto.Changeset.cast(params, Map.keys(types))
    |> Ecto.Changeset.validate_required([:title])
  end

  defp filter_map_presence_to_user_typing({user_login, presence}, presence_ref) do
    if Enum.any?(presence.metas, &(&1.typing && &1.phx_ref != presence_ref)),
      do: [user_login],
    else: []
  end

  defp subscribe_topic!(socket) do
    if connected?(socket) do
      :ok = subscribe(issue_topic(socket))
    end
    socket
  end

  defp issue_topic(socket), do: "issue:#{socket.assigns.issue.id}"
end
