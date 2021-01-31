defmodule GitGud.CommitLineReviewTest do
  use GitGud.DataCase, async: true
  use GitGud.DataFactory

  alias GitGud.User
  alias GitGud.Repo
  alias GitGud.RepoStorage
  alias GitGud.CommitLineReview
  alias GitGud.CommentQuery

  setup :create_user
  setup :create_repo

  test "creates a new commit line review with valid params", %{user: user, repo: repo} do
    commit_oid = "ed8c92b7bd7c367e4138b49e56fa7f3e648cd056"
    blob_oid = "4e55d5b11d5e24bf91babf58914159881c227233"
    hunk = 1
    line = 1
    assert {:ok, comment} = CommitLineReview.add_comment(repo, commit_oid, blob_oid, hunk, line, user, "This is a new commit line review.")
    assert comment.body == "This is a new commit line review."
    assert comment.thread_table == "commit_line_reviews_comments"
    assert review = CommentQuery.thread(comment)
    assert review.commit_oid == commit_oid
    assert review.blob_oid == blob_oid
    assert review.hunk == hunk
    assert review.line == line
  end

  test "when commit line review exists adds new comment", %{user: user, repo: repo} do
    commit_oid = "ed8c92b7bd7c367e4138b49e56fa7f3e648cd056"
    blob_oid = "4e55d5b11d5e24bf91babf58914159881c227233"
    hunk = 1
    line = 2
    assert {:ok, comment1} = CommitLineReview.add_comment(repo, commit_oid, blob_oid, hunk, line, user, "This is the first comment.")
    assert {:ok, comment2} = CommitLineReview.add_comment(repo, commit_oid, blob_oid, hunk, line, user, "This is the second comment.")
    assert CommentQuery.thread(comment1) == CommentQuery.thread(comment2)
  end

  #
  # Helpers
  #

  defp create_user(context) do
    Map.put(context, :user, User.create!(factory(:user)))
  end

  defp create_repo(context) do
    repo = Repo.create!(factory(:repo, context.user))
    on_exit fn ->
      File.rm_rf(RepoStorage.workdir(repo))
    end
    Map.put(context, :repo, repo)
  end
end
