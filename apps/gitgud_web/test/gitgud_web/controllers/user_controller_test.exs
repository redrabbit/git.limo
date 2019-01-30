defmodule GitGud.Web.UserControllerTest do
  use GitGud.Web.ConnCase, async: true
  use GitGud.Web.DataFactory

  alias GitGud.Email
  alias GitGud.User
  alias GitGud.UserQuery
  alias GitGud.Repo

  test "renders user registration form", %{conn: conn} do
    conn = get(conn, Routes.user_path(conn, :new))
    assert html_response(conn, 200) =~ ~s(<h1 class="title has-text-grey-lighter">Register</h1>)
  end

  test "creates user with valid params", %{conn: conn} do
    user_params = factory(:user)
    conn = post(conn, Routes.user_path(conn, :create), user: user_params)
    user = UserQuery.by_login(user_params.login)
    assert get_flash(conn, :info) == "Welcome #{user.login}."
    assert get_session(conn, :user_id) == user.id
    assert redirected_to(conn) == Routes.user_path(conn, :show, user)
  end

  test "fails to create user with invalid login", %{conn: conn} do
    user_params = factory(:user)
    conn = post(conn, Routes.user_path(conn, :create), user: Map.delete(user_params, :login))
    assert get_flash(conn, :error) == "Something went wrong! Please check error(s) below."
    assert html_response(conn, 400) =~ ~s(<h1 class="title has-text-grey-lighter">Register</h1>)
    conn = post(conn, Routes.user_path(conn, :create), user: Map.update!(user_params, :login, &(&1<>".")))
    assert get_flash(conn, :error) == "Something went wrong! Please check error(s) below."
    assert html_response(conn, 400) =~ ~s(<h1 class="title has-text-grey-lighter">Register</h1>)
    conn = post(conn, Routes.user_path(conn, :create), user: Map.update!(user_params, :login, &binary_part(&1, 0, 2)))
    assert get_flash(conn, :error) == "Something went wrong! Please check error(s) below."
    assert html_response(conn, 400) =~ ~s(<h1 class="title has-text-grey-lighter">Register</h1>)
  end

  test "fails to create user with invalid email", %{conn: conn} do
    user_params = factory(:user)
    conn = post(conn, Routes.user_path(conn, :create), user: Map.delete(user_params, :emails))
    assert get_flash(conn, :error) == "Something went wrong! Please check error(s) below."
    assert html_response(conn, 400) =~ ~s(<h1 class="title has-text-grey-lighter">Register</h1>)
    conn = post(conn, Routes.user_path(conn, :create), user: Map.update!(user_params, :emails, fn emails -> List.update_at(emails, 0, &%{&1|address: &1.address <> ".0"}) end))
    assert get_flash(conn, :error) == "Something went wrong! Please check error(s) below."
    assert html_response(conn, 400) =~ ~s(<h1 class="title has-text-grey-lighter">Register</h1>)
  end

  describe "when user exists" do
    setup :create_user

    test "renders user profile", %{conn: conn, user: user} do
      conn = get(conn, Routes.user_path(conn, :show, user))
      assert html_response(conn, 200) =~ ~s(<h1 class="title">#{user.name}</h1>)
      assert html_response(conn, 200) =~ ~s(<h2 class="subtitle">#{user.login}</h2>)
      assert html_response(conn, 200) =~ ~s(Nothing to see here.)
    end

    test "renders user edit form if authenticated", %{conn: conn, user: user} do
      conn = Plug.Test.init_test_session(conn, user_id: user.id)
      conn = get(conn, Routes.user_path(conn, :edit_profile))
      assert html_response(conn, 200) =~ ~s(<h1 class="title">Settings</h1>)
    end

    test "fails to render user edit form if not authenticated", %{conn: conn} do
      conn = get(conn, Routes.user_path(conn, :edit_profile))
      assert html_response(conn, 401) =~ "Unauthorized"
    end

    test "updates user profile with valid params", %{conn: conn, user: user} do
      conn = Plug.Test.init_test_session(conn, user_id: user.id)
      conn = put(conn, Routes.user_path(conn, :update_profile), profile: %{name: "Alice", bio: "I love programming!", public_email_id: hd(user.emails).id, url: "http://www.example.com"})
      user = UserQuery.by_id(user.id, preload: :emails)
      assert user.name == "Alice"
      assert user.bio == "I love programming!"
      assert user.public_email_id == hd(user.emails).id
      assert user.url == "http://www.example.com"
      assert get_flash(conn, :info) == "Profile updated."
      assert redirected_to(conn) == Routes.user_path(conn, :edit_profile)
    end

    test "fails to update user profile with invalid public email", %{conn: conn, user: user} do
      conn = Plug.Test.init_test_session(conn, user_id: user.id)
      conn = put(conn, Routes.user_path(conn, :update_profile), profile: %{public_email_id: 0})
      assert get_flash(conn, :error) == "Something went wrong! Please check error(s) below."
      assert html_response(conn, 400) =~ ~s(<h1 class="title">Settings</h1>)
    end

    test "fails to update user profile with invalid url", %{conn: conn, user: user} do
      conn = Plug.Test.init_test_session(conn, user_id: user.id)
      conn = put(conn, Routes.user_path(conn, :update_profile), profile: %{url: "oops"})
      assert get_flash(conn, :error) == "Something went wrong! Please check error(s) below."
      assert html_response(conn, 400) =~ ~s(<h1 class="title">Settings</h1>)
    end
  end

  describe "when user exists and has repositories" do
    setup [:create_user, :create_repos]

    test "renders user profile", %{conn: conn, user: user, repos: repos} do
      conn = get(conn, Routes.user_path(conn, :show, user))
      assert html_response(conn, 200) =~ ~s(<h1 class="title">#{user.name}</h1>)
      assert html_response(conn, 200) =~ ~s(<h2 class="subtitle">#{user.login}</h2>)
      for repo <- repos do
        assert html_response(conn, 200) =~ ~s(<a class="card-header-title" href="#{Routes.codebase_path(conn, :show, user, repo)}">#{repo.name}</a>)
      end
    end
  end

  #
  # Helpers
  #

  defp create_user(context) do
    user = User.create!(factory(:user))
    on_exit fn ->
      File.rmdir(Path.join(Repo.root_path, user.login))
    end
    Map.put(context, :user, struct(user, emails: Enum.map(user.emails, &Email.verify!/1)))
  end

  defp create_repos(context) do
    repos = Enum.take(Stream.repeatedly(fn -> Repo.create!(factory(:repo, context.user)) end), 3)
    on_exit fn ->
      for repo <- repos do
        File.rm_rf(Repo.workdir(repo))
      end
    end
    Map.put(context, :repos, repos)
  end
end
