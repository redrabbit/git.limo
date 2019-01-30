defmodule GitGud.Web.SessionControllerTest do
  use GitGud.Web.ConnCase, async: true
  use GitGud.Web.DataFactory

  alias GitGud.Email
  alias GitGud.User

  test "renders login form", %{conn: conn} do
    conn = get(conn, Routes.session_path(conn, :new))
    assert html_response(conn, 200) =~ ~s(<h1 class="title has-text-grey-lighter">Login</h1>)
  end

  describe "when user exists" do
    setup :create_user

    test "creates session with valid credentials", %{conn: conn, user: user} do
      conn = post(conn, Routes.session_path(conn, :create), session: %{login: hd(user.emails).address, password: "qwertz"})
      assert get_flash(conn, :info) == "Welcome #{user.login}."
      assert redirected_to(conn) == Routes.user_path(conn, :show, user)
      conn = post(conn, Routes.session_path(conn, :create), session: %{login: user.login, password: "qwertz"})
      assert get_flash(conn, :info) == "Welcome #{user.login}."
      assert redirected_to(conn) == Routes.user_path(conn, :show, user)
    end

    test "fails to create session with invalid credentials", %{conn: conn, user: user} do
      conn = post(conn, Routes.session_path(conn, :create), session: %{login: hd(user.emails).address, password: "qwerty"})
      assert get_flash(conn, :error) == "Wrong login credentials."
      assert html_response(conn, 401) =~ ~s(<h1 class="title has-text-grey-lighter">Login</h1>)
      conn = post(conn, Routes.session_path(conn, :create), session: %{login: user.login, password: "qwerty"})
      assert get_flash(conn, :error) == "Wrong login credentials."
      assert html_response(conn, 401) =~ ~s(<h1 class="title has-text-grey-lighter">Login</h1>)
    end

    test "deletes session", %{conn: conn, user: user} do
      conn = Plug.Test.init_test_session(conn, user_id: user.id)
      conn = get(conn, Routes.session_path(conn, :delete))
      refute get_session(conn, :user_id)
      assert get_flash(conn, :info) == "Logged out."
      assert redirected_to(conn) == Routes.landing_page_path(conn, :index)
    end
  end

  #
  # Helpers
  #

  defp create_user(context) do
    user = User.create!(factory(:user))
    Map.put(context, :user, struct(user, emails: Enum.map(user.emails, &Email.verify!/1)))
  end
end
