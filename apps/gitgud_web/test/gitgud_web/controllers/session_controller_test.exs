defmodule GitGud.Web.SessionControllerTest do
  use GitGud.Web.ConnCase, async: true
  use GitGud.Web.DataFactory

  alias GitGud.User

  test "renders login form", %{conn: conn} do
    conn = get(conn, Routes.session_path(conn, :new))
    assert html_response(conn, 200) =~ ~s(<h1 class="title">Login</h1>)
  end

  describe "when user exists" do
    setup :create_user

    test "creates session with valid credentials", %{conn: conn, user: user} do
      conn = post(conn, Routes.session_path(conn, :create), session: %{email_or_username: hd(user.emails).email, password: "qwertz"})
      assert get_flash(conn, :info) == "Logged in."
      assert redirected_to(conn) == Routes.user_path(conn, :show, user)
      conn = post(conn, Routes.session_path(conn, :create), session: %{email_or_username: user.username, password: "qwertz"})
      assert get_flash(conn, :info) == "Logged in."
      assert redirected_to(conn) == Routes.user_path(conn, :show, user)
    end

    test "fails to create session with invalid credentials", %{conn: conn, user: user} do
      conn = post(conn, Routes.session_path(conn, :create), session: %{email_or_username: hd(user.emails).email, password: "qwerty"})
      assert get_flash(conn, :error) == "Wrong login credentials"
      assert html_response(conn, 401) =~ ~s(<h1 class="title">Login</h1>)
      conn = post(conn, Routes.session_path(conn, :create), session: %{email_or_username: user.username, password: "qwerty"})
      assert get_flash(conn, :error) == "Wrong login credentials"
      assert html_response(conn, 401) =~ ~s(<h1 class="title">Login</h1>)
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
    Map.put(context, :user, User.create!(factory(:user)))
  end
end
