defmodule GitGud.IssueQueryTest do
  use GitGud.DataCase, async: true
  use GitGud.DataFactory

  alias GitGud.User
  alias GitGud.Repo
  alias GitGud.RepoStorage
  alias GitGud.Issue
  alias GitGud.IssueQuery

  setup [:create_user, :create_repo, :create_issues]

  test "gets single issue by id", %{issues: issues} do
    for issue <- issues do
      assert issue.id == IssueQuery.by_id(issue.id).id
    end
  end

  test "gets single issue by number from repository", %{repo: repo, issues: issues} do
    for issue <- issues do
      assert issue.id == IssueQuery.repo_issue(repo, issue.number).id
    end
  end

  test "gets all issues from repository", %{repo: repo, issues: issues} do
    results = IssueQuery.repo_issues(repo)
    assert Enum.count(results) == length(issues)
    assert Enum.all?(results, fn issue -> issue.id in Enum.map(issues, &(&1.id)) end)
  end

  test "gets opened issues from repository", %{repo: repo, issues: issues} do
    :ok = Enum.each(Enum.drop(issues, 2), &Issue.close!/1)
    results = IssueQuery.repo_issues(repo, status: :open)
    assert Enum.count(results) == 2
  end

  test "gets closed issues from repository", %{repo: repo, issues: issues} do
    :ok = Enum.each(Enum.drop(issues, 2), &Issue.close!/1)
    results = IssueQuery.repo_issues(repo, status: :close)
    assert Enum.count(results) == length(issues) - 2
  end

  test "counts all issues from repository", %{repo: repo, issues: issues} do
    assert IssueQuery.count_repo_issues(repo) == length(issues)
  end

  test "counts opened issues from repository", %{repo: repo, issues: issues} do
    :ok = Enum.each(Enum.drop(issues, 2), &Issue.close!/1)
    assert IssueQuery.count_repo_issues(repo, status: :open) == 2
  end

  test "counts closed issues from repository", %{repo: repo, issues: issues} do
    :ok = Enum.each(Enum.drop(issues, 2), &Issue.close!/1)
    assert IssueQuery.count_repo_issues(repo, status: :close) == length(issues) - 2
  end

  test "counts issues grouped by status from repository", %{repo: repo, issues: issues} do
    :ok = Enum.each(Enum.drop(issues, 2), &Issue.close!/1)
    assert IssueQuery.count_repo_issues_by_status(repo) == %{open: 2, close: length(issues) - 2}
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

  defp create_issues(context) do
    issues = Enum.take(Stream.repeatedly(fn -> Issue.create!(factory(:issue, [context.repo, context.user])) end), 3)
    Map.put(context, :issues, issues)
  end
end
