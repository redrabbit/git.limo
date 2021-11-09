defmodule GitGud.Web.CommitDiffLive do
  @moduledoc """
  Live view responsible for rendering diffs between Git commits.
  """

  use GitGud.Web, :live_view

  alias GitRekt.GitRepo
  alias GitRekt.GitAgent

  alias GitGud.DB
  alias GitGud.DBQueryable

  alias GitGud.User
  alias GitGud.CommitLineReview
  alias GitGud.Comment
  alias GitGud.GPGKey

  alias GitGud.UserQuery
  alias GitGud.RepoQuery
  alias GitGud.ReviewQuery
  alias GitGud.CommentQuery

  alias GitGud.Web.Presence

  import GitRekt.Git, only: [oid_fmt: 1, oid_parse: 1]

  import GitGud.Web.Endpoint, only: [broadcast_from: 4, subscribe: 1]

  import GitGud.Web.CodebaseView

  #
  # Callbacks
  #

  @impl true
  def mount(%{"user_login" => user_login, "repo_name" => repo_name} = _params, session, socket) do
    {
      :ok,
      socket
      |> authenticate(session)
      |> assign_repo!(user_login, repo_name)
      |> assign_repo_permissions()
      |> assign_repo_open_issue_count()
      |> assign_agent!(),
      temporary_assigns: [reviews: []]
    }
  end

  @impl true
  def handle_params(_params, _uri, socket) when is_nil(socket.assigns.repo.pushed_at) do
    {:noreply, assign_page_title(socket)}
  end

  def handle_params(%{"oid" => commit_oid} = _params, _uri, socket) do
    {
      :noreply,
      socket
      |> assign_diff!(oid_parse(commit_oid))
      |> assign_reviews()
      |> assign_comment_count()
      |> assign_page_title()
      |> assign_presence!()
      |> assign_presence_map()
      |> assign_users_typing()
      |> subscribe_topic!()
    }
  end

  @impl true
  def handle_event("add_comment", %{"oid" => oid, "hunk" => hunk, "line" => line, "comment" => comment_params}, socket) do
    case CommitLineReview.add_comment(socket.assigns.repo, socket.assigns.commit.oid, oid_parse(oid), String.to_integer(hunk), String.to_integer(line), current_user(socket), comment_params["body"], with_review: true) do
      {:ok, comment, review} ->
        send_update(GitGud.Web.CommitDiffDynamicReviewsLive, id: "dynamic-reviews", reviews: [struct(review, comments: [comment])])
        broadcast_from(self(), commit_topic(socket), "add_review", %{review_id: review.id})
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
        broadcast_from(self(), commit_topic(socket), "add_comment", %{review_id: review_id, comment_id: comment.id})
        {
          :noreply,
          socket
          |> assign_presence_typing!(review_id, false)
          |> push_event("add_comment", %{comment_id: comment.id})
        }
      {:error, changeset} ->
        send_update(GitGud.Web.CommentFormLive, id: "review-#{review_id}-comment-form", changeset: changeset)
        {:noreply, assign_presence_typing!(socket, review_id, false)}
    end
  end

  def handle_event("validate_comment", %{"oid" => oid, "hunk" => hunk, "line" => line, "comment" => comment_params}, socket) do
    send_update(GitGud.Web.CommentFormLive, id: "review-#{oid}-#{hunk}-#{line}-comment-form", changeset: Comment.changeset(%Comment{}, comment_params))
    {:noreply, socket}
  end

  def handle_event("validate_comment", %{"review_id" => review_id, "comment" => comment_params}, socket) do
    changeset = Comment.changeset(%Comment{}, comment_params)
    send_update(GitGud.Web.CommentFormLive, id: "review-#{review_id}-comment-form", changeset: Comment.changeset(%Comment{}, comment_params))
    {:noreply, assign_presence_typing!(socket, String.to_integer(review_id), !!Ecto.Changeset.get_change(changeset, :body))}
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
    {:noreply, assign_presence_typing!(socket, String.to_integer(review_id), false)}
  end

  @impl true
  def handle_info({:update_comment, comment_id}, socket) do
    broadcast_from(self(), commit_topic(socket), "update_comment", %{comment_id: comment_id})
    {:noreply, push_event(socket, "update_comment", %{comment_id: comment_id})}
  end

  def handle_info({:delete_comment, comment_id}, socket) do
    broadcast_from(self(), commit_topic(socket), "delete_comment", %{comment_id: comment_id})
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

  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", payload: %{joins: joins, leaves: leaves}}, socket) do
    {:noreply,
     socket
     |> assign_presence_map(joins, leaves)
     |> send_presence_updates(joins, leaves)
    }
  end

  #
  # Helpers
  #

  defp assign_repo!(socket, user_login, repo_name) do
    query = DBQueryable.query({RepoQuery, :user_repo_query}, [user_login, repo_name], viewer: current_user(socket))
    assign(socket, :repo, DB.one!(query))
  end

  defp assign_repo_open_issue_count(socket) do
    assign(socket, :repo_open_issue_count, GitGud.IssueQuery.count_repo_issues(socket.assigns.repo, status: :open))
  end

  defp assign_repo_permissions(socket) do
    if connected?(socket),
      do: assign(socket, :repo_permissions, RepoQuery.permissions(socket.assigns.repo, current_user(socket))),
    else: assign(socket, :repo_permissions, [])
  end

  defp assign_agent!(socket) do
    assign(socket, :agent, resolve_agent!(socket.assigns.repo))
  end

  defp assign_diff!(socket, oid) do
    assigns = resolve_commit_diff!(socket.assigns.agent, oid)
    assigns = Map.update!(assigns, :commit_info, &resolve_db_commit_info/1)
    assign(socket, assigns)
  end

  defp assign_reviews(socket) do
    assign(socket, :reviews, ReviewQuery.commit_line_reviews(socket.assigns.repo, socket.assigns.commit.oid, preload: {:comments, :author}))
  end

  defp assign_comment_count(socket) do
    assign(socket, :comment_count, Map.new(Enum.group_by(socket.assigns.reviews, &(&1.blob_oid)), fn {blob_oid, reviews} ->
      {blob_oid, Enum.reduce(reviews, 0, fn review, acc -> acc + Enum.count(review.comments) end)}
    end))
  end

  defp assign_page_title(socket) do
    assign(socket, :page_title, GitGud.Web.CodebaseView.title(socket.assigns[:live_action], socket.assigns))
  end

  defp assign_presence!(socket) do
    if connected?(socket) && authenticated?(socket) do
      {:ok, presence_ref} = Presence.track(self(), commit_topic(socket), current_user(socket).login, %{typing: []})
      assign(socket, presence_ref: presence_ref, presence_typing: [])
    else
      assign(socket, presence_ref: nil, presence_typing: [])
    end
  end

  defp assign_presence_map(socket) do
    assign(socket, :presence_map, Presence.list(commit_topic(socket)))
  end

  defp assign_presence_map(socket, joins, leaves) do
    presences = socket.assigns.presence_map
    presences = Enum.reduce(leaves, presences, fn {key, _presence}, acc -> Map.delete(acc, key) end)
    presences = Enum.reduce(joins, presences, fn {key, presence}, acc -> Map.put(acc, key, presence) end)
    assign(socket, :presence_map, presences)
  end

  defp assign_presence_typing!(socket, review_id, true) do
    unless review_id in socket.assigns.presence_typing do
      {:ok, presence_ref} = Presence.update(self(), commit_topic(socket), current_user(socket).login, &update_in(&1, [:typing], fn reviews -> Enum.uniq([review_id|reviews]) end))
      assign(socket, presence_ref: presence_ref, presence_typing: Enum.uniq([review_id|socket.assigns.presence_typing]))
    else
      socket
    end
  end

  defp assign_presence_typing!(socket, review_id, false) do
    if review_id in socket.assigns.presence_typing do
      {:ok, presence_ref} = Presence.update(self(), commit_topic(socket), current_user(socket).login, &update_in(&1, [:typing], fn reviews -> List.delete(reviews, review_id) end))
      assign(socket, presence_ref: presence_ref, presence_typing: List.delete(socket.assigns.presence_typing, review_id))
    else
      socket
    end
  end

  defp assign_users_typing(socket) do
    reviews_typing = Enum.reduce(socket.assigns.presence_map, %{}, &reduce_presence_reviews(&1, &2, socket.assigns.presence_ref))
    assign(socket, :reviews, Enum.map(socket.assigns.reviews, &map_review_users_typing(&1, reviews_typing)))
  end

  defp resolve_agent!(repo) do
    case GitRepo.get_agent(repo) do
      {:ok, agent} ->
        agent
      {:error, error} ->
        raise error
    end
  end

  defp resolve_commit_diff!(agent, oid) do
    case GitAgent.transaction(agent, &resolve_commit_diff(&1, oid)) do
      {:ok, {commit, commit_info, diff_stats, diff_deltas}} ->
        %{commit: commit, commit_info: commit_info, diff_stats: diff_stats, diff_deltas: diff_deltas}
      {:error, error} ->
        raise error
    end
  end

  defp resolve_commit_diff(agent, oid) do
    with {:ok, commit} <- GitAgent.object(agent, oid),
         {:ok, commit_info} <- resolve_commit_info(agent, commit),
         {:ok, diff} <- GitAgent.diff(agent, Enum.at(commit_info.parents, 0), commit),
         {:ok, diff_stats} <- GitAgent.diff_stats(agent, diff),
         {:ok, diff_deltas} <- GitAgent.diff_deltas(agent, diff) do
      {:ok, {commit, commit_info, diff_stats, diff_deltas}}
    end
  end

  defp resolve_commit_info(agent, commit) do
    with {:ok, timestamp} <- GitAgent.commit_timestamp(agent, commit),
         {:ok, message} <- GitAgent.commit_message(agent, commit),
         {:ok, author} <- GitAgent.commit_author(agent, commit),
         {:ok, committer} <- GitAgent.commit_committer(agent, commit),
         {:ok, parents} <- GitAgent.commit_parents(agent, commit) do
      gpg_sig =
        case GitAgent.commit_gpg_signature(agent, commit) do
          {:ok, gpg_sig} -> gpg_sig
          {:error, _reason} -> nil
        end
      {:ok, %{
        author: author,
        committer: committer,
        message: message,
        timestamp: timestamp,
        gpg_sig: gpg_sig,
        parents: Enum.to_list(parents)}
      }
    end
  end

  defp resolve_db_commit_info(commit_info) do
    users = UserQuery.by_email(Enum.uniq([commit_info.author.email, commit_info.committer.email]), preload: [:emails, :gpg_keys])
    author = resolve_db_user(commit_info.author, users)
    committer = resolve_db_user(commit_info.committer, users)
    gpg_key = resolve_db_user_gpg_key(commit_info.gpg_sig, committer)
    Map.merge(commit_info, %{author: author, committer: committer, gpg_key: gpg_key})
  end

  defp resolve_db_user(%{email: email} = map, users) do
    Enum.find(users, map, fn user -> email in Enum.map(user.emails, &(&1.address)) end)
  end

  defp resolve_db_user_gpg_key(gpg_sig, %User{} = user) when not is_nil(gpg_sig) do
    gpg_key_id =
      gpg_sig
      |> GPGKey.decode!()
      |> GPGKey.parse!()
      |> get_in([:sig, :sub_pack, :issuer])
    Enum.find(user.gpg_keys, &String.ends_with?(&1.key_id, gpg_key_id))
  end

  defp resolve_db_user_gpg_key(_gpg_sig, _user), do: nil

  defp map_review_users_typing(review, reviews_typing) when is_struct(review, CommitLineReview), do: map_review_users_typing(Map.from_struct(review), reviews_typing)
  defp map_review_users_typing(review, reviews_typing), do: Map.put(review, :users_typing, Map.get(reviews_typing, review.id, []))

  defp reduce_presence_reviews({user_login, presence}, acc, presence_ref) do
    Enum.reduce(presence.metas, acc, fn meta, acc ->
      if meta.phx_ref != presence_ref,
        do: Enum.reduce(meta.typing, acc, fn review_id, acc -> Map.update(acc, review_id, [user_login], &[user_login|&1]) end),
      else: acc
    end)
  end

  defp send_presence_updates(socket, joins, leaves) do
    reviews_typing = Enum.reduce(socket.assigns.presence_map, %{}, &reduce_presence_reviews(&1, &2, socket.assigns.presence_ref))
    join_ids = Map.keys(Enum.reduce(joins, %{}, &reduce_presence_reviews(&1, &2, socket.assigns.presence_ref)))
    leave_ids = Map.keys(Enum.reduce(leaves, %{}, &reduce_presence_reviews(&1, &2, socket.assigns.presence_ref)))
    Enum.concat(join_ids, leave_ids)
    |> Enum.uniq()
    |> Enum.each(&send_update(GitGud.Web.CommitLineReviewLive, id: "review-#{&1}", review_id: &1, comments: [], users_typing: Map.get(reviews_typing, &1, [])))
    socket
  end

  defp subscribe_topic!(socket) do
    if connected?(socket) do
      :ok = subscribe(commit_topic(socket))
    end
    socket
  end

  defp commit_topic(socket), do: "commit:#{socket.assigns.repo.id}-#{oid_fmt(socket.assigns.commit.oid)}"
end
