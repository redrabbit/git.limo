defmodule GitGud.Web.RepoControllerTest do
  use GitGud.Web.ConnCase, async: true
  use GitGud.Web.DataFactory

  alias GitGud.User
  alias GitGud.Repo
  alias GitGud.RepoStorage
  alias GitGud.RepoQuery
  alias GitGud.Email

  alias GitGud.Web.LayoutView

  setup :create_user

  test "renders repository creation form if authenticated", %{conn: conn, user: user} do
    conn = Plug.Test.init_test_session(conn, user_id: user.id)
    conn = get(conn, Routes.repo_path(conn, :new))
    assert {:ok, html} = Floki.parse_document(html_response(conn, 200))
    assert Floki.text(Floki.find(html, "title")) == LayoutView.title(conn)
  end

  test "fails to render repository creation form if not authenticated", %{conn: conn} do
    conn = get(conn, Routes.repo_path(conn, :new))
    assert {:ok, html} = Floki.parse_document(html_response(conn, 401))
    assert Floki.text(Floki.find(html, "title")) == "Oops, something went wrong!"
  end

  test "creates repository with valid params", %{conn: conn, user: user} do
    repo_params = factory(:repo)
    conn = Plug.Test.init_test_session(conn, user_id: user.id)
    conn = post(conn, Routes.repo_path(conn, :create), repo: repo_params)
    repo = RepoQuery.user_repo(user, repo_params.name)
    assert get_flash(conn, :info) == "Repository '#{repo.owner_login}/#{repo.name}' created."
    assert redirected_to(conn) == Routes.codebase_path(conn, :show, user, repo)
    File.rm_rf!(RepoStorage.workdir(repo))
  end

  test "fails to create repository with invalid name", %{conn: conn, user: user} do
    repo_params = factory(:repo)
    conn = Plug.Test.init_test_session(conn, user_id: user.id)
    conn = post(conn, Routes.repo_path(conn, :create), repo: Map.delete(repo_params, :name))
    assert get_flash(conn, :error) == "Something went wrong! Please check error(s) below."
    assert {:ok, html} = Floki.parse_document(html_response(conn, 400))
    assert Floki.text(Floki.find(html, "title")) == LayoutView.title(conn)
    conn = post(conn, Routes.repo_path(conn, :create), repo: Map.update!(repo_params, :name, &(&1<>"$")))
    assert get_flash(conn, :error) == "Something went wrong! Please check error(s) below."
    assert {:ok, html} = Floki.parse_document(html_response(conn, 400))
    assert Floki.text(Floki.find(html, "title")) == LayoutView.title(conn)
    conn = post(conn, Routes.repo_path(conn, :create), repo: Map.update!(repo_params, :name, &binary_part(&1, 0, 2)))
    assert get_flash(conn, :error) == "Something went wrong! Please check error(s) below."
    assert {:ok, html} = Floki.parse_document(html_response(conn, 400))
    assert Floki.text(Floki.find(html, "title")) == LayoutView.title(conn)
  end

  describe "when user has repositories" do
    setup :create_repos

    test "renders user repositories", %{conn: conn, user: user, repos: repos} do
      conn = get(conn, Routes.repo_path(conn, :index, user))
      assert {:ok, html} = Floki.parse_document(html_response(conn, 200))
      assert Floki.text(Floki.find(html, "title")) == LayoutView.title(conn)
      html_repo = Enum.map(Floki.find(html, ".card .card-header-title"), &String.trim(Floki.text(&1)))
      for repo <- repos do
        assert repo.name in html_repo
      end
    end
  end

  describe "when repository exists" do
    setup :create_repo

    test "renders repository edit form if authenticated user is owner", %{conn: conn, user: user, repo: repo} do
      conn = Plug.Test.init_test_session(conn, user_id: user.id)
      conn = get(conn, Routes.repo_path(conn, :edit, user, repo))
      assert {:ok, html} = Floki.parse_document(html_response(conn, 200))
      assert Floki.text(Floki.find(html, "title")) == LayoutView.title(conn)
    end

    test "fails to render repository edit form if not authenticated", %{conn: conn, user: user, repo: repo} do
      conn = get(conn, Routes.repo_path(conn, :edit, user, repo))
      assert {:ok, html} = Floki.parse_document(html_response(conn, 401))
      assert Floki.text(Floki.find(html, "title")) == "Oops, something went wrong!"
    end

    test "fails to render repository edit form if not authorized", %{conn: conn, user: user1, repo: repo} do
      user2 = User.create!(factory(:user))
      conn = Plug.Test.init_test_session(conn, user_id: user2.id)
      conn = get(conn, Routes.repo_path(conn, :edit, user1, repo))
      assert {:ok, html} = Floki.parse_document(html_response(conn, 403))
      assert Floki.text(Floki.find(html, "title")) == "Oops, something went wrong!"
    end

    test "updates repository with valid params", %{conn: conn, user: user, repo: repo} do
      conn = Plug.Test.init_test_session(conn, user_id: user.id)
      conn = put(conn, Routes.repo_path(conn, :edit, user, repo), repo: %{name: "my-awesome-project", description: "This project is really awesome!"})
      repo = RepoQuery.by_id(repo.id)
      assert repo.name == "my-awesome-project"
      assert repo.description == "This project is really awesome!"
      assert get_flash(conn, :info) == "Repository '#{repo.owner_login}/#{repo.name}' updated."
      assert redirected_to(conn) == Routes.repo_path(conn, :edit, user, repo)
      File.rm_rf!(RepoStorage.workdir(repo))
    end

    test "fails to update repository with invalid name", %{conn: conn, user: user, repo: repo} do
      conn = Plug.Test.init_test_session(conn, user_id: user.id)
      conn = put(conn, Routes.repo_path(conn, :update, user, repo), repo: %{name: "my awesome project"})
      assert get_flash(conn, :error) == "Something went wrong! Please check error(s) below."
      assert {:ok, html} = Floki.parse_document(html_response(conn, 400))
      assert Floki.text(Floki.find(html, "title")) == LayoutView.title(conn)
      conn = put(conn, Routes.repo_path(conn, :update, user, repo), repo: %{name: "ap"})
      assert get_flash(conn, :error) == "Something went wrong! Please check error(s) below."
      assert {:ok, html} = Floki.parse_document(html_response(conn, 400))
      assert Floki.text(Floki.find(html, "title")) == LayoutView.title(conn)
    end

    test "deletes repository", %{conn: conn, user: user, repo: repo} do
      conn = Plug.Test.init_test_session(conn, user_id: user.id)
      conn = delete(conn, Routes.repo_path(conn, :delete, user, repo))
      assert get_flash(conn, :info) == "Repository '#{repo.owner_login}/#{repo.name}' deleted."
      assert redirected_to(conn) == Routes.user_path(conn, :show, user)
    end
  end

  #
  # Helpers
  #

  defp create_user(context) do
    user = User.create!(factory(:user))
    on_exit fn ->
      File.rmdir(Path.join(Keyword.fetch!(Application.get_env(:gitgud, RepoStorage), :git_root), user.login))
    end
    Map.put(context, :user, struct(user, emails: Enum.map(user.emails, &Email.verify!/1)))
  end

  defp create_repo(context) do
    repo = Repo.create!(context.user, factory(:repo))
    on_exit fn ->
      File.rm_rf(RepoStorage.workdir(repo))
    end
    Map.put(context, :repo, repo)
  end

  defp create_repos(context) do
    repos = Enum.take(Stream.repeatedly(fn -> Repo.create!(context.user, factory(:repo)) end), 3)
    on_exit fn ->
      for repo <- repos do
        File.rm_rf(RepoStorage.workdir(repo))
      end
    end
    Map.put(context, :repos, repos)
  end
end
