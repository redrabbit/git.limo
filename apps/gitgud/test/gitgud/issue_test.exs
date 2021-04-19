defmodule GitGud.IssueTest do
  use GitGud.DataCase, async: true
  use GitGud.DataFactory

  alias GitGud.User
  alias GitGud.Repo
  alias GitGud.RepoStorage
  alias GitGud.Issue

  setup :create_user
  setup :create_repo

  test "creates a new issue with valid params", %{user: user, repo: repo} do
    params = factory(:issue)
    assert {:ok, issue} = Issue.create(repo, user, params)
    assert issue.title == params.title
    assert issue.status == "open"
    assert issue.repo_id == repo.id
    assert issue.author_id == user.id
    assert comment = issue.comment
    assert comment.body == params.comment.body
    assert comment.thread_table == "issues_comments"
    assert comment.repo_id == repo.id
    assert comment.author_id == user.id
  end

  test "fails to create a new issue with invalid title", %{user: user, repo: repo} do
    params = factory(:issue)
    assert {:error, changeset} = Issue.create(repo, user, Map.delete(params, :title))
    assert "can't be blank" in errors_on(changeset).title
  end

  test "fails to create a new issue without comment", %{user: user, repo: repo} do
    params = factory(:issue)
    assert {:error, changeset} = Issue.create(repo, user, Map.put(params, :comment, %{}))
    assert "can't be blank" in errors_on(changeset).comment.body
  end

  describe "when issue exists" do
    setup :create_issue

    test "adds new comment", %{user: user, repo: repo, issue: issue1} do
      assert {:ok, comment} = Issue.add_comment(issue1, user, "Hello this is a comment.")
      issue2 = DB.preload(issue1, :replies)
      assert comment.id == hd(issue2.replies).id
      assert comment.body == "Hello this is a comment."
      assert comment.repo_id == repo.id
      assert comment.author_id == user.id
      assert comment.thread_table == "issues_comments"
    end

    test "updates issue title", %{issue: issue1} do
      assert {:ok, issue2} = Issue.update_title(issue1, "This is the new title")
      assert issue2.title == "This is the new title"
      assert List.last(issue2.events) == %{
        "old_title" => issue1.title,
        "new_title" => "This is the new title",
        "timestamp" => NaiveDateTime.to_iso8601(issue2.updated_at),
        "type" => "title_update"
      }
    end

    test "update issue labels", %{repo: repo, issue: issue1} do
      labels_ids = Enum.map(repo.issue_labels, &(&1.id))
      Issue.update_labels!(issue1, {Enum.drop(labels_ids, 1), []})
      push = Enum.take(labels_ids, 1)
      pull = Enum.slice(labels_ids, 1..2)
      assert {:ok, issue2} = Issue.update_labels(issue1, {push, pull})
      assert length(issue2.labels) == length(labels_ids) - 2
      refute Enum.find(issue2.labels, &(&1.id in pull))
      assert List.last(issue2.events) == %{
        "timestamp" => NaiveDateTime.to_iso8601(issue2.updated_at),
        "push" => push,
        "pull" => pull,
        "type" => "labels_update"
      }
    end

    test "closes issue", %{issue: issue1} do
      assert {:ok, issue2} = Issue.close(issue1)
      assert issue2.status == "close"
      assert List.last(issue2.events) == %{
        "timestamp" => NaiveDateTime.to_iso8601(issue2.updated_at),
        "type" => "close"
      }
    end

    test "reopens issue", %{issue: issue1} do
      assert {:ok, issue2} =Issue.reopen(Issue.close!(issue1))
      assert issue2.status == "open"
      assert List.last(issue2.events) == %{
        "timestamp" => NaiveDateTime.to_iso8601(issue2.updated_at),
        "type" => "reopen"
      }
    end

    test "adds issue labels", %{repo: repo, issue: issue1} do
      push = Enum.map(Enum.take(repo.issue_labels, 2), &(&1.id))
      assert {:ok, issue2} = Issue.update_labels(issue1, {push, []})
      assert length(issue2.labels) == 2
      assert Enum.all?(issue2.labels, &(&1.id in push))
      assert List.last(issue2.events) == %{
        "push" => push,
        "pull" => [],
        "timestamp" => NaiveDateTime.to_iso8601(issue2.updated_at),
        "type" => "labels_update"
      }
    end

    test "removes issue labels", %{repo: repo, issue: issue1} do
      labels_ids = Enum.map(repo.issue_labels, &(&1.id))
      Issue.update_labels!(issue1, {Enum.take(labels_ids, 4), []})
      pull = Enum.take(labels_ids, 2)
      assert {:ok, issue2} = Issue.update_labels(issue1, {[], pull})
      assert length(issue2.labels) == 2
      refute Enum.find(issue2.labels, &(&1.id in pull))
      assert List.last(issue2.events) == %{
        "timestamp" => NaiveDateTime.to_iso8601(issue2.updated_at),
        "push" => [],
        "pull" => pull,
        "type" => "labels_update"
      }
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

  defp create_issue(context) do
    Map.put(context, :issue, Issue.create!(context.repo, context.user, factory(:issue)))
  end
end
