defmodule GitGud.Web.RepoControllerTest do
  use GitGud.Web.ConnCase, async: true
  use GitGud.Web.DataFactory

  alias GitGud.User
  alias GitGud.Repo
  alias GitGud.RepoQuery

  setup :create_user

  test "renders repository creation form if authenticated", %{conn: conn, user: user} do
    conn = Plug.Test.init_test_session(conn, user_id: user.id)
    conn = get(conn, repo_path(conn, :new))
    assert html_response(conn, 200) =~ ~s(<h1 class="title">Create a new repository</h1>)
  end

  test "fails to render repository creation form if not authenticated", %{conn: conn} do
    conn = get(conn, repo_path(conn, :new))
    assert html_response(conn, 401) =~ "Unauthorized"
  end

  test "creates repository with valid params", %{conn: conn, user: user} do
    repo_params = factory(:repo)
    conn = Plug.Test.init_test_session(conn, user_id: user.id)
    conn = post(conn, repo_path(conn, :create), repo: repo_params)
    repo = RepoQuery.user_repo(user, repo_params.name)
    assert get_flash(conn, :info) == "Repository created."
    assert redirected_to(conn) == codebase_path(conn, :show, user, repo)
    File.rm_rf!(Repo.workdir(repo))
  end

  test "fails to create repository with invalid name", %{conn: conn, user: user} do
    repo_params = factory(:repo)
    conn = Plug.Test.init_test_session(conn, user_id: user.id)
    conn = post(conn, repo_path(conn, :create), repo: Map.delete(repo_params, :name))
    assert get_flash(conn, :error) == "Something went wrong! Please check error(s) below."
    assert html_response(conn, 400) =~ ~s(<h1 class="title">Create a new repository</h1>)
    conn = post(conn, repo_path(conn, :create), repo: Map.update!(repo_params, :name, &(&1<>"$")))
    assert get_flash(conn, :error) == "Something went wrong! Please check error(s) below."
    assert html_response(conn, 400) =~ ~s(<h1 class="title">Create a new repository</h1>)
    conn = post(conn, repo_path(conn, :create), repo: Map.update!(repo_params, :name, &binary_part(&1, 0, 2)))
    assert get_flash(conn, :error) == "Something went wrong! Please check error(s) below."
    assert html_response(conn, 400) =~ ~s(<h1 class="title">Create a new repository</h1>)
  end

  describe "when repository exists" do
    setup :create_repo

    test "renders repository edit form if authenticated user is owner", %{conn: conn, user: user, repo: repo} do
      conn = Plug.Test.init_test_session(conn, user_id: user.id)
      conn = get(conn, repo_path(conn, :edit, user, repo))
      assert html_response(conn, 200) =~ ~s(<h2 class="subtitle">Settings</h2>)
    end

    test "fails to render repository edit form if not authenticated", %{conn: conn, user: user, repo: repo} do
      conn = get(conn, repo_path(conn, :edit, user, repo))
      assert html_response(conn, 401) =~ "Unauthorized"
    end

    test "fails to render repository edit form if not authorized", %{conn: conn, user: user1, repo: repo} do
      user2 = User.create!(factory(:user))
      conn = Plug.Test.init_test_session(conn, user_id: user2.id)
      conn = get(conn, repo_path(conn, :edit, user1, repo))
      assert html_response(conn, 401) =~ "Unauthorized"
    end

    test "updates repository with valid params", %{conn: conn, user: user, repo: repo} do
      conn = Plug.Test.init_test_session(conn, user_id: user.id)
      conn = put(conn, repo_path(conn, :edit, user, repo), repo: %{name: "my-awesome-project", description: "This project is really awesome!"})
      repo = RepoQuery.by_id(repo.id)
      assert repo.name == "my-awesome-project"
      assert repo.description == "This project is really awesome!"
      assert get_flash(conn, :info) == "Repository updated."
      assert redirected_to(conn) == repo_path(conn, :edit, user, repo)
      File.rm_rf!(Repo.workdir(repo))
    end

    test "fails to update repository with invalid name", %{conn: conn, user: user, repo: repo} do
      conn = Plug.Test.init_test_session(conn, user_id: user.id)
      conn = put(conn, repo_path(conn, :update, user, repo), repo: %{name: "my awesome project"})
      assert get_flash(conn, :error) == "Something went wrong! Please check error(s) below."
      assert html_response(conn, 400) =~ ~s(<h2 class="subtitle">Settings</h2>)
      conn = put(conn, repo_path(conn, :update, user, repo), repo: %{name: "ap"})
      assert get_flash(conn, :error) == "Something went wrong! Please check error(s) below."
      assert html_response(conn, 400) =~ ~s(<h2 class="subtitle">Settings</h2>)
    end
  end

  #
  # Helpers
  #

  defp create_user(context) do
    Map.put(context, :user, User.create!(factory(:user)))
  end

  defp create_repo(context) do
    {repo, _git_handle} = Repo.create!(factory(:repo, context.user))
    on_exit fn ->
      File.rm_rf!(Repo.workdir(repo))
    end
    Map.put(context, :repo, repo)
  end
end
