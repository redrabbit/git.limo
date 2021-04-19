defmodule GitGud.ReviewQueryTest do
  use GitGud.DataCase, async: true
  use GitGud.DataFactory

  alias GitGud.User
  alias GitGud.Repo
  alias GitGud.RepoStorage
  alias GitGud.ReviewQuery
  alias GitGud.CommitLineReview
  alias GitGud.CommentQuery

  setup [:create_user, :create_repo, :create_commit_line_reviews]

  test "gets single commit line review by id", %{commit_line_reviews: reviews} do
    for {review, _comments} <- reviews do
      assert review.id == ReviewQuery.commit_line_review(review.id).id
    end
  end

  test "gets single commit line review by commit line", %{repo: repo, commit_line_reviews: reviews} do
    for {review, _comments} <- reviews do
      assert review.id == ReviewQuery.commit_line_review(repo, review.commit_oid, review.blob_oid, review.hunk, review.line).id
    end
  end

  test "gets multiple commit line reviews from commit", %{repo: repo, commit_line_reviews: reviews} do
    commits_reviews = Enum.group_by(reviews, &(elem(&1, 0).commit_oid), &elem(&1, 0))
    for {commit_oid, reviews} <- commits_reviews do
      results = ReviewQuery.commit_line_reviews(repo, commit_oid)
      assert Enum.count(results) == length(reviews)
      assert Enum.all?(results, fn review -> review.id in Enum.map(reviews, &(&1.id)) end)
    end
  end

  test "counts all commit line review comments from commit", %{repo: repo, commit_line_reviews: reviews} do
    commits_comments = Enum.group_by(reviews, &(elem(&1, 0).commit_oid), &elem(&1, 1))
    commits_comments = Enum.map(commits_comments, fn {commit_oid, comments} -> {commit_oid, List.flatten(comments)} end)
    for {commit_oid, comments} <- commits_comments do
      assert ReviewQuery.count_comments(repo, commit_oid) == length(comments)
    end
  end

  #
  # Helpers
  #


  defp create_user(context) do
    Map.put(context, :user, User.create!(factory(:user)))
  end

  defp create_repo(context) do
    repo = Repo.create!(context.user, factory(:repo))
    on_exit fn ->
      File.rm_rf(RepoStorage.workdir(repo))
    end
    Map.put(context, :repo, repo)
  end

  defp create_commit_line_reviews(context) do
    reviews =
      Enum.take(Stream.repeatedly(fn ->
        commit_oid = generate_oid(Enum.random(0..99))
        Enum.take(Stream.repeatedly(fn ->
          blob_oid = generate_oid(Enum.random(100..199))
          hunk = Enum.random(0..99)
          line = Enum.random(0..99)
          comments = Enum.take(Stream.repeatedly(fn ->
            CommitLineReview.add_comment!(context.repo, commit_oid, blob_oid, hunk, line, context.user, "This is a comment.")
          end), 2)
          {CommentQuery.thread(hd(comments)), comments}
        end), 2)
      end), 2)
    Map.put(context, :commit_line_reviews, List.flatten(reviews))
  end

  defp generate_oid(n), do: :crypto.hash(:sha, to_string(n)) |> Base.encode16(case: :lower)
end
