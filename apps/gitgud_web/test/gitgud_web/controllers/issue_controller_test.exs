defmodule GitGud.Web.IssueControllerTest do
  use GitGud.Web.ConnCase, async: true
  use GitGud.Web.DataFactory

  alias GitGud.DB
  alias GitGud.User
  alias GitGud.Email
  alias GitGud.Repo
  alias GitGud.RepoStorage
  alias GitGud.Issue

  alias GitGud.Web.LayoutView

  import GitGud.Web.DateTimeFormatter

  setup [:create_user, :create_repo]

  test "renders issue creation form if authenticated", %{conn: conn, user: user, repo: repo} do
    conn = Plug.Test.init_test_session(conn, user_id: user.id)
    conn = get(conn, Routes.issue_path(conn, :new, user, repo))
    assert {:ok, html} = Floki.parse_document(html_response(conn, 200))
    assert Floki.text(Floki.find(html, "title")) == LayoutView.title(conn)
  end

  test "fails to render issue creation form if not authenticated", %{conn: conn, user: user, repo: repo} do
    conn = get(conn, Routes.issue_path(conn, :new, user, repo))
    assert {:ok, html} = Floki.parse_document(html_response(conn, 401))
    assert Floki.text(Floki.find(html, "title")) == "Oops, something went wrong!"
  end

  test "creates issue with valid params", %{conn: conn, user: user, repo: repo} do
    issue_params = factory(:issue)
    conn = Plug.Test.init_test_session(conn, user_id: user.id)
    conn = post(conn, Routes.issue_path(conn, :create, user, repo), issue: issue_params)
    assert %{"number" => num_str} = Regex.named_captures(~r/Issue #(?<number>\d+) created./, get_flash(conn, :info))
    assert redirected_to(conn) == Routes.issue_path(conn, :show, user, repo, String.to_integer(num_str))
  end

  test "fails to create issue without title", %{conn: conn, user: user, repo: repo} do
    issue_params = factory(:issue)
    conn = Plug.Test.init_test_session(conn, user_id: user.id)
    conn = post(conn, Routes.issue_path(conn, :create, user, repo), issue: Map.delete(issue_params, :title))
    assert get_flash(conn, :error) == "Something went wrong! Please check error(s) below."
    assert {:ok, html} = Floki.parse_document(html_response(conn, 400))
    assert Floki.text(Floki.find(html, "title")) == LayoutView.title(conn)
  end

  describe "when issues exists" do
    setup :create_issues

    test "renders issues", %{conn: conn, user: user, repo: repo, issues: issues} do
      conn = get(conn, Routes.issue_path(conn, :index, user, repo))
      assert html_response(conn, 200) =~ ~s(<h2 class="subtitle">Issues</h2>)
      assert {:ok, html} = Floki.parse_document(html_response(conn, 200))
      assert Floki.text(Floki.find(html, "title")) == LayoutView.title(conn)
      html_issues = Floki.find(html, "table.issues-table tr")
      for issue <- issues do
        assert {issue_title, issue_info, _issue_labels} = find_html_issue(html_issues, issue)
        assert issue_title == issue.title
        assert issue_info == "##{issue.number} opened #{datetime_format_str(issue.inserted_at, "{relative}")} by #{user.login}"
      end
    end
  end

  #
  # Helpers
  #

  defp create_user(context) do
    user = User.create!(factory(:user))
    on_exit fn ->
      File.rmdir(Path.join(Application.fetch_env!(:gitgud, :git_root), user.login))
    end
    Map.put(context, :user, struct(user, emails: Enum.map(user.emails, &Email.verify!/1)))
  end

  defp create_repo(context) do
    repo = Repo.create!(context.user, factory(:repo))
    repo = DB.preload(repo, [:issue_labels])
    on_exit fn ->
      File.rm_rf(RepoStorage.workdir(repo))
    end
    Map.put(context, :repo, repo)
  end

  defp create_issues(context) do
    issues = Stream.repeatedly(fn -> Issue.create!(context.repo, context.user, factory(:issue)) end)
    issues = Enum.take(issues, 5)
    Map.put(context, :issues, issues)
  end

  defp find_html_issue(html_issues, issue) do
    Enum.find_value(html_issues, fn html_issue ->
      info = String.trim(Floki.text(Floki.find(html_issue, ".issue-info")))
      if String.starts_with?(info, "##{issue.number}") do
        html_title = Floki.find(html_issue, ".issue-title")
        html_issue_labels = Floki.find(html_title, "button")
        title = Floki.text(Floki.find(html_title, "a"))
        labels = Enum.map(html_issue_labels, &Floki.text/1)
        {title, info, labels}
      end
    end)
  end
end
