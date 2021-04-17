defmodule GitGud.Web.CommitDiffLive do
  @moduledoc """
  Live view responsible for rendering diffs between Git commits.
  """

  use GitGud.Web, :live_view

  alias GitRekt.GitAgent

  alias GitGud.CommitLineReview
  alias GitGud.Comment

  alias GitGud.RepoQuery
  alias GitGud.ReviewQuery
  alias GitGud.CommentQuery

  import GitRekt.Git, only: [oid_fmt: 1, oid_parse: 1]

  import GitGud.Web.Endpoint, only: [broadcast_from: 4, subscribe: 1]

  import GitGud.Web.CodebaseView

  #
  # Callbacks
  #

  @impl true
  def mount(_params, %{"repo_id" => repo_id, "commit_oid" => oid} = session, socket) do
    {
      :ok,
      socket
      |> authenticate(session)
      |> assign_new(:repo, fn -> RepoQuery.by_id(repo_id) end)
      |> assign_repo_permissions()
      |> assign_agent!()
      |> assign_commit!(oid)
      |> assign_diff!()
      |> assign_reviews()
      |> assign_comment_count()
      |> subscribe_topic(),
      temporary_assigns: [reviews: []]
    }
  end

  @impl true
  def handle_event("add_comment", %{"oid" => oid, "hunk" => hunk, "line" => line, "comment" => comment_params}, socket) do
    case CommitLineReview.add_comment(socket.assigns.repo, socket.assigns.commit.oid, oid_parse(oid), String.to_integer(hunk), String.to_integer(line), current_user(socket), comment_params["body"], with_review: true) do
      {:ok, comment, review} ->
        send_update(GitGud.Web.CommitDiffDynamicReviewsLive, id: "dynamic-reviews", reviews: [struct(review, comments: [comment])])
        broadcast_from(self(), "commit:#{socket.assigns.repo.id}-#{oid_fmt(socket.assigns.commit.oid)}", "add_review", %{review_id: review.id})
        {
          :noreply,
          socket
          |> push_event("add_comment", %{comment_id: comment.id})
          |> push_event("delete_review_form", %{oid: oid, hunk: hunk, line: line})
        }
      {:error, changeset} ->
        send_update(GitGud.Web.CommentFormLive, id: "review-#{oid}-#{hunk}-#{line}-comment-form", changeset: changeset)
        {:noreply, socket}
    end
  end

  def handle_event("add_comment", %{"review_id" => review_id, "comment" => comment_params}, socket) do
    review_id = String.to_integer(review_id)
    case CommitLineReview.add_comment({socket.assigns.repo.id, review_id}, current_user(socket), comment_params["body"]) do
      {:ok, comment} ->
        send_update(GitGud.Web.CommentFormLive, id: "review-#{review_id}-comment-form", minimized: true, changeset: Comment.changeset(%Comment{}))
        send_update(GitGud.Web.CommitLineReviewLive, id: "review-#{review_id}", review_id: review_id, comments: [comment])
        broadcast_from(self(), "commit:#{socket.assigns.repo.id}-#{oid_fmt(socket.assigns.commit.oid)}", "add_comment", %{review_id: review_id, comment_id: comment.id})
        {:noreply, push_event(socket, "add_comment", %{comment_id: comment.id})}
      {:error, changeset} ->
        send_update(GitGud.Web.CommentFormLive, id: "review-#{review_id}-comment-form", changeset: changeset)
        {:noreply, socket}
    end
  end

  def handle_event("validate_comment", %{"oid" => oid, "hunk" => hunk, "line" => line, "comment" => comment_params}, socket) do
    send_update(GitGud.Web.CommentFormLive, id: "review-#{oid}-#{hunk}-#{line}-comment-form", changeset: Comment.changeset(%Comment{}, comment_params))
    {:noreply, socket}
  end

  def handle_event("validate_comment", %{"review_id" => review_id, "comment" => comment_params}, socket) do
    send_update(GitGud.Web.CommentFormLive, id: "review-#{review_id}-comment-form", changeset: Comment.changeset(%Comment{}, comment_params))
    {:noreply, socket}
  end

  def handle_event("add_review_form", %{"oid" => oid, "hunk" => hunk, "line" => line}, socket) do
    send_update(GitGud.Web.CommitDiffDynamicFormsLive, id: "dynamic-forms", forms: [{oid_parse(oid), String.to_integer(hunk), String.to_integer(line)}])
    {:noreply, socket}
  end

  def handle_event("reset_review_form", %{"oid" => oid, "hunk" => hunk, "line" => line}, socket) do
    {:noreply, push_event(socket, "delete_review_form", %{oid: oid, hunk: hunk, line: line})}
  end

  def handle_event("reset_review_form", %{"review_id" => review_id}, socket) do
    send_update(GitGud.Web.CommentFormLive, id: "review-#{review_id}-comment-form", minimized: true, changeset: Comment.changeset(%Comment{}))
    {:noreply, socket}
  end

  @impl true
  def handle_info({:update_comment, comment_id}, socket) do
    broadcast_from(self(), "commit:#{socket.assigns.repo.id}-#{oid_fmt(socket.assigns.commit.oid)}", "update_comment", %{comment_id: comment_id})
    {:noreply, push_event(socket, "update_comment", %{comment_id: comment_id})}
  end

  def handle_info({:delete_comment, comment_id}, socket) do
    broadcast_from(self(), "commit:#{socket.assigns.repo.id}-#{oid_fmt(socket.assigns.commit.oid)}", "delete_comment", %{comment_id: comment_id})
    {:noreply, push_event(socket, "delete_comment", %{comment_id: comment_id})}
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "add_review", payload: %{review_id: review_id}}, socket) do
    review = ReviewQuery.commit_line_review(review_id, preload: {:comments, :author})
    send_update(GitGud.Web.CommitDiffDynamicReviewsLive, id: "dynamic-reviews", reviews: [review])
    {:noreply, push_event(socket, "add_comment", %{comment_id: hd(review.comments).id})}
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "add_comment", payload: %{review_id: review_id, comment_id: comment_id}}, socket) do
    comment = CommentQuery.by_id(comment_id, preload: :author)
    send_update(GitGud.Web.CommitLineReviewLive, id: "review-#{review_id}", review_id: review_id, comments: [comment])
    {:noreply, push_event(socket, "add_comment", %{comment_id: comment_id})}
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "update_comment", payload: %{comment_id: comment_id}}, socket) do
    comment = CommentQuery.by_id(comment_id, preload: :author)
    send_update(GitGud.Web.CommentLive, id: "comment-#{comment_id}", comment: comment)
    {:noreply, push_event(socket, "update_comment", %{comment_id: comment_id})}
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "delete_comment", payload: %{comment_id: comment_id}}, socket) do
    {:noreply, push_event(socket, "delete_comment", %{comment_id: comment_id})}
  end

  #
  # Helpers
  #

  defp subscribe_topic(socket) when not socket.connected?, do: socket
  defp subscribe_topic(socket) do
    subscribe("commit:#{socket.assigns.repo.id}-#{oid_fmt(socket.assigns.commit.oid)}")
    socket
  end

  defp assign_repo_permissions(socket) when not socket.connected?, do: assign(socket, :repo_permissions, [])
  defp assign_repo_permissions(socket) do
    assign(socket, :repo_permissions, RepoQuery.permissions(socket.assigns.repo, current_user(socket)))
  end

  defp assign_agent!(socket) do
    case GitAgent.unwrap(socket.assigns.repo) do
      {:ok, agent} ->
        assign(socket, :agent, agent)
      {:error, reason} ->
        raise RuntimeError, message: reason
    end
  end

  defp assign_commit!(socket, oid) do
    assign_new(socket, :commit, fn -> resolve_commit!(socket.assigns.agent, oid) end)
  end

  defp assign_diff!(socket) do
    assign(socket, resolve_diff!(socket.assigns.agent, socket.assigns.commit))
  end

  defp assign_reviews(socket) do
    assign(socket, :reviews, ReviewQuery.commit_line_reviews(socket.assigns.repo, socket.assigns.commit, preload: {:comments, :author}))
  end

  defp assign_comment_count(socket) do
    assign(socket, :comment_count, Map.new(Enum.group_by(socket.assigns.reviews, &(&1.blob_oid)), fn {blob_oid, reviews} ->
      {blob_oid, Enum.reduce(reviews, 0, fn review, acc -> acc + Enum.count(review.comments) end)}
    end))
  end

  defp resolve_commit!(agent, oid) do
    case GitAgent.object(agent, oid) do
      {:ok, commit} ->
        commit
      {:error, reason} ->
        raise RuntimeError, message: reason
    end
  end

  defp resolve_diff!(agent, commit) do
    with {:ok, commit_parents} <- GitAgent.commit_parents(agent, commit),
         {:ok, diff} <- GitAgent.diff(agent, Enum.at(commit_parents, 0), commit),
         {:ok, diff_stats} <- GitAgent.diff_stats(agent, diff),
         {:ok, diff_deltas} <- GitAgent.diff_deltas(agent, diff) do
      %{diff_stats: diff_stats, diff_deltas: diff_deltas}
    else
      {:error, reason} ->
        raise RuntimeError, message: reason
    end
  end
end
