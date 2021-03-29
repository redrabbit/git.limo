defmodule GitGud.Web.CommitDiffLive do
  use GitGud.Web, :live_view

  alias GitRekt.GitAgent

  alias GitGud.DB
  alias GitGud.DBQueryable

  alias GitGud.CommitLineReview
  alias GitGud.Comment

  alias GitGud.RepoQuery
  alias GitGud.ReviewQuery

  import GitRekt.Git, only: [oid_fmt: 1]

  import GitGud.Web.Endpoint, only: [broadcast_from: 4, subscribe: 1]

  import GitGud.Web.CodebaseView

  #
  # Callbacks
  #

  @impl true
  def mount(_params, %{"repo_id" => repo_id, "commit_oid" => oid} = session, socket) do
    subscribe("commit:#{oid_fmt(oid)}")
    {
      :ok,
      socket
      |> authenticate(session)
      |> assign_repo!(repo_id)
      |> assign_agent!()
      |> assign_commit!(oid)
      |> assign_diff!()
      |> assign_reviews()
      |> assign_comment_count()
    }
  end

  @impl true
  def handle_event("add_comment", %{"review_id" => review_id, "comment" => comment_params}, socket) do
    review_id = String.to_integer(review_id)
    review_index = Enum.find_index(socket.assigns.reviews, &(&1.id == review_id))
    case CommitLineReview.add_comment(Enum.at(socket.assigns.reviews, review_index), current_user(socket), comment_params["body"]) do
      {:ok, comment} ->
        send_update(GitGud.Web.CommentFormLive, id: "review-#{review_id}-comment-form", minimized: true, changeset: Comment.changeset(%Comment{}))
        broadcast_from(self(), "commit:#{oid_fmt(socket.assigns.commit.oid)}", "add_comment", %{review_id: review_id, comment: comment})
        {
          :noreply,
          socket
          |> assign(:reviews, List.update_at(socket.assigns.reviews, review_index, &struct(&1, comments: &1.comments ++ [comment])))
          |> assign_comment_count()
        }
      {:error, changeset} ->
        send_update(GitGud.Web.CommentFormLive, id: "review-#{review_id}-comment-form", changeset: changeset)
        {:noreply, socket}
    end
  end

  def handle_event("validate_comment", %{"review_id" => review_id, "comment" => comment_params}, socket) do
    send_update(GitGud.Web.CommentFormLive, id: "review-#{review_id}-comment-form", changeset: Comment.changeset(%Comment{}, comment_params))
    {:noreply, socket}
  end

  def handle_event("reset_comment", %{"review_id" => review_id}, socket) do
    send_update(GitGud.Web.CommentFormLive, id: "review-#{review_id}-comment-form", minimized: true, changeset: Comment.changeset(%Comment{}))
    {:noreply, socket}
  end

  @impl true
  def handle_info({:update_comment, comment}, socket) do
    broadcast_from(self(), "commit:#{oid_fmt(socket.assigns.commit.oid)}", "update_comment", %{comment: comment})
    {:noreply, assign(socket, :reviews, update_review_comment(socket.assigns.reviews, comment))}
  end

  def handle_info({:delete_comment, comment}, socket) do
    broadcast_from(self(), "commit:#{oid_fmt(socket.assigns.commit.oid)}", "delete_comment", %{comment: comment})
    {
      :noreply,
      socket
      |> assign(:reviews, delete_review_comment(socket.assigns.reviews, comment))
      |> assign_comment_count()
    }
  end

  def handle_info(%Phoenix.Socket.Broadcast{topic: topic, event: "add_comment", payload: %{review_id: review_id, comment: comment}}, socket) do
    if topic == "commit:" <> oid_fmt(socket.assigns.commit.oid) do
      review_index = Enum.find_index(socket.assigns.reviews, &(&1.id == review_id))
      {
        :noreply,
        socket
        |> assign(:reviews, List.update_at(socket.assigns.reviews, review_index, &struct(&1, comments: &1.comments ++ [comment])))
        |> assign_comment_count()
      }
    else
      {:noreply, socket}
    end
  end

  def handle_info(%Phoenix.Socket.Broadcast{topic: topic, event: "update_comment", payload: %{comment: comment}}, socket) do
    if topic == "commit:" <> oid_fmt(socket.assigns.commit.oid) do
      {:noreply, assign(socket, :reviews, update_review_comment(socket.assigns.reviews, comment))}
    else
      {:noreply, socket}
    end
  end

  def handle_info(%Phoenix.Socket.Broadcast{topic: topic, event: "delete_comment", payload: %{comment: comment}}, socket) do
    if topic == "commit:" <> oid_fmt(socket.assigns.commit.oid) do
      {
        :noreply,
        socket
        |> assign(:reviews, delete_review_comment(socket.assigns.reviews, comment))
        |> assign_comment_count()
      }
    else
      {:noreply, socket}
    end
  end

  #
  # Helpers
  #

  defp assign_repo!(socket, repo_id) do
    assign_new(socket, :repo, fn ->
      DB.one!(DBQueryable.query({RepoQuery, :repo_query}, [repo_id], viewer: current_user(socket)))
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

  defp find_review_comment_index(reviews, comment_id) do
    Enum.find_value(Enum.with_index(reviews), fn {review, review_index} ->
      if comment_index = Enum.find_index(review.comments, &(&1.id == comment_id)) do
        {review_index, length(review.comments) > 1 && comment_index}
      end
    end)
  end

  defp update_review_comment(reviews, comment) do
    {review_index, comment_index} = find_review_comment_index(reviews, comment.id)
    List.update_at(reviews, review_index, fn review ->
      struct(review, comments: List.replace_at(review.comments, comment_index || 0, comment))
    end)
  end

  defp delete_review_comment(reviews, comment) do
    case find_review_comment_index(reviews, comment.id) do
      {review_index, nil} ->
        List.delete_at(reviews, review_index)
      {review_index, comment_index} ->
        List.update_at(reviews, review_index, fn review ->
          struct(review, comments: List.delete_at(review.comments, comment_index))
        end)
    end
  end
end
