defmodule GitGud.Web.UserControllerTest do
  use GitGud.Web.ConnCase, async: true
  use GitGud.Web.DataFactory

  alias GitGud.User
  alias GitGud.UserQuery
  alias GitGud.Repo

  test "renders user registration form", %{conn: conn} do
    conn = get(conn, Routes.user_path(conn, :new))
    assert html_response(conn, 200) =~ ~s(<h1 class="title">Register</h1>)
  end

  test "creates user with valid params", %{conn: conn} do
    user_params = factory(:user)
    conn = post(conn, Routes.user_path(conn, :create), user: user_params)
    user = UserQuery.by_username(user_params.username)
    assert get_flash(conn, :info) == "Welcome!"
    assert get_session(conn, :user_id) == user.id
    assert redirected_to(conn) == Routes.user_path(conn, :show, user)
  end

  test "fails to create user with invalid username", %{conn: conn} do
    user_params = factory(:user)
    conn = post(conn, Routes.user_path(conn, :create), user: Map.delete(user_params, :username))
    assert get_flash(conn, :error) == "Something went wrong! Please check error(s) below."
    assert html_response(conn, 400) =~ ~s(<h1 class="title">Register</h1>)
    conn = post(conn, Routes.user_path(conn, :create), user: Map.update!(user_params, :username, &(&1<>".")))
    assert get_flash(conn, :error) == "Something went wrong! Please check error(s) below."
    assert html_response(conn, 400) =~ ~s(<h1 class="title">Register</h1>)
    conn = post(conn, Routes.user_path(conn, :create), user: Map.update!(user_params, :username, &binary_part(&1, 0, 2)))
    assert get_flash(conn, :error) == "Something went wrong! Please check error(s) below."
    assert html_response(conn, 400) =~ ~s(<h1 class="title">Register</h1>)
  end

  test "fails to create user with invalid email", %{conn: conn} do
    user_params = factory(:user)
    conn = post(conn, Routes.user_path(conn, :create), user: Map.delete(user_params, :emails))
    assert get_flash(conn, :error) == "Something went wrong! Please check error(s) below."
    assert html_response(conn, 400) =~ ~s(<h1 class="title">Register</h1>)
    conn = post(conn, Routes.user_path(conn, :create), user: Map.update!(user_params, :emails, fn emails -> List.update_at(emails, 0, &%{&1|email: &1.email <> ".0"}) end))
    assert get_flash(conn, :error) == "Something went wrong! Please check error(s) below."
    assert html_response(conn, 400) =~ ~s(<h1 class="title">Register</h1>)
  end

  describe "when user exists" do
    setup :create_user

    test "renders user profile", %{conn: conn, user: user} do
      user_repos = Enum.take(Stream.repeatedly(fn -> elem(Repo.create!(factory(:repo, user)), 0) end), 3)
      conn = get(conn, Routes.user_path(conn, :show, user))
      assert html_response(conn, 200) =~ ~s(<h1 class="title">#{user.name}</h1>)
      assert html_response(conn, 200) =~ ~s(<h2 class="subtitle">#{user.username}</h2>)
      for repo <- user_repos do
        assert html_response(conn, 200) =~ ~s(<a class="card-header-title" href="#{Routes.codebase_path(conn, :show, user, repo)}">#{repo.name}</a>)
        File.rm_rf!(Repo.workdir(repo))
      end
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
      conn = put(conn, Routes.user_path(conn, :update_profile), profile: %{name: "Alice"})
      user = UserQuery.by_id(user.id)
      assert user.name == "Alice"
      assert get_flash(conn, :info) == "Profile updated."
      assert redirected_to(conn) == Routes.user_path(conn, :edit_profile)
    end
  end

  #
  # Helpers
  #

  defp create_user(context) do
    Map.put(context, :user, User.create!(factory(:user)))
  end
end
