defmodule GitGud.Web.IssueLabelControllerTest do
  use GitGud.Web.ConnCase, async: true
  use GitGud.Web.DataFactory

  alias GitGud.DB
  alias GitGud.User
  alias GitGud.Repo
  alias GitGud.RepoStorage

  alias GitGud.Web.LayoutView

  setup [:create_user, :create_repo]

  test "renders issue labels", %{conn: conn, user: user, repo: repo} do
    conn = get(conn, Routes.issue_label_path(conn, :index, user, repo))
    assert {:ok, html} = Floki.parse_document(html_response(conn, 200))
    assert Floki.text(Floki.find(html, "title")) == LayoutView.title(conn)
    html_issue_labels = Floki.find(html, "button.issue-label")
    for issue_label <- repo.issue_labels do
      assert html_issue_label = Enum.find(html_issue_labels, &(Floki.text(&1) == issue_label.name))
      assert Floki.attribute(html_issue_label, "style") == ["background-color: ##{issue_label.color}"]
    end
  end

  describe "when authenticated user is owner" do
    test "renders issue labels update form", %{conn: conn, user: user, repo: repo} do
      conn = Plug.Test.init_test_session(conn, user_id: user.id)
      conn = get(conn, Routes.issue_label_path(conn, :index, user, repo))
      assert {:ok, html} = Floki.parse_document(html_response(conn, 200))
      assert Floki.text(Floki.find(html, "title")) == LayoutView.title(conn)
      html_color_pickers = Floki.find(html, ".color-picker")
      for issue_label <- repo.issue_labels do
        assert Enum.find(html_color_pickers, &(Floki.attribute(Floki.find(&1, "input"), "value") == [issue_label.name, issue_label.color]))
      end
    end

    test "adds new label", %{conn: conn, user: user, repo: repo} do
      conn = Plug.Test.init_test_session(conn, user_id: user.id)
      issue_labels_params = Enum.map(repo.issue_labels, &Map.take(&1, [:id, :name, :color]))
      issue_labels_params = [%{name: "test", color: "ff0000"}|issue_labels_params]
      conn = put(conn, Routes.issue_label_path(conn, :update, user, repo), repo: %{issue_labels: Map.new(Enum.with_index(issue_labels_params), fn {label, index} -> {index, label} end)})
      assert get_flash(conn, :info) == "Issue labels updated."
      assert redirected_to(conn) == Routes.issue_label_path(conn, :index, user, repo)
      repo = DB.preload(repo, :issue_labels, force: true)
      for issue_label <- repo.issue_labels do
        assert Enum.find(issue_labels_params, &(issue_label.name == &1.name && issue_label.color == &1.color))
      end
    end

    test "updates label with valid params", %{conn: conn, user: user, repo: repo} do
      conn = Plug.Test.init_test_session(conn, user_id: user.id)
      [%{id: issue_label_id}|issue_labels_params] = Enum.map(repo.issue_labels, &Map.take(&1, [:id, :name, :color]))
      issue_labels_params = [%{id: issue_label_id, name: "test", color: "ff0000"}|issue_labels_params]
      conn = put(conn, Routes.issue_label_path(conn, :update, user, repo), repo: %{issue_labels: Map.new(Enum.with_index(issue_labels_params), fn {label, index} -> {index, label} end)})
      assert get_flash(conn, :info) == "Issue labels updated."
      assert redirected_to(conn) == Routes.issue_label_path(conn, :index, user, repo)
      repo = DB.preload(repo, :issue_labels, force: true)
      for issue_label <- repo.issue_labels do
        assert Enum.find(issue_labels_params, &(issue_label.name == &1.name && issue_label.color == &1.color))
      end
    end

    test "fails to update label with invalid params", %{conn: conn, user: user, repo: repo} do
      conn = Plug.Test.init_test_session(conn, user_id: user.id)
      issue_labels_params = [%{name: "test"}]
      conn = put(conn, Routes.issue_label_path(conn, :update, user, repo), repo: %{issue_labels: Map.new(Enum.with_index(issue_labels_params), fn {label, index} -> {index, label} end)})
      assert get_flash(conn, :error) == "Something went wrong! Please check error(s) below."
      assert {:ok, html} = Floki.parse_document(html_response(conn, 400))
      assert Floki.text(Floki.find(html, "title")) == LayoutView.title(conn)
    end

    test "deletes label", %{conn: conn, user: user, repo: repo} do
      conn = Plug.Test.init_test_session(conn, user_id: user.id)
      [_issue_label|issue_labels_params] = Enum.map(repo.issue_labels, &Map.take(&1, [:id, :name, :color]))
      conn = put(conn, Routes.issue_label_path(conn, :update, user, repo), repo: %{issue_labels: Map.new(Enum.with_index(issue_labels_params), fn {label, index} -> {index, label} end)})
      assert get_flash(conn, :info) == "Issue labels updated."
      assert redirected_to(conn) == Routes.issue_label_path(conn, :index, user, repo)
      repo = DB.preload(repo, :issue_labels, force: true)
      for issue_label <- repo.issue_labels do
        assert Enum.find(issue_labels_params, &(issue_label.name == &1.name && issue_label.color == &1.color))
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
    Map.put(context, :user, user)
  end

  defp create_repo(context) do
    repo = Repo.create!(context.user, factory(:repo))
    repo = DB.preload(repo, :issue_labels)
    on_exit fn ->
      File.rm_rf(RepoStorage.workdir(repo))
    end
    Map.put(context, :repo, repo)
  end
end
