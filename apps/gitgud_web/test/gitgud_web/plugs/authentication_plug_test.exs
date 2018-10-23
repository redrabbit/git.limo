defmodule GitGud.Web.AuthenticationPlugTest do
  use GitGud.Web.ConnCase
  use GitGud.Web.DataFactory

  alias GitGud.User

  import GitGud.Web.AuthenticationPlug, except: [call: 2, init: 1]

  setup :create_user

  test "authenticates with valid user session", %{conn: conn, user: user} do
    conn = Plug.Test.init_test_session(conn, user_id: user.id)
    conn = authenticate_session(conn, [])
    assert authenticated?(conn)
    assert current_user(conn).id == user.id
  end

  test "fails to authenticates with invalid user session", %{conn: conn} do
    conn = Plug.Test.init_test_session(conn, user_id: 0)
    conn = authenticate_session(conn, [])
    refute authenticated?(conn)
  end

  test "authenticates with valid bearer token", %{conn: conn, user: user} do
    conn = put_req_header(conn, "authorization", "Bearer " <> Phoenix.Token.sign(GitGud.Web.Endpoint, "bearer", user.id))
    conn = authenticate_bearer_token(conn, [])
    assert authenticated?(conn)
    assert current_user(conn).id == user.id
  end

  test "fails to authenticates with invalid bearer token", %{conn: conn} do
    conn = put_req_header(conn, "authorization", "Bearer " <> Phoenix.Token.sign(GitGud.Web.Endpoint, "bearer", 0))
    conn = authenticate_bearer_token(conn, [])
    refute authenticated?(conn)
  end

  test "ensures connection is authenticated", %{conn: conn, user: user} do
    conn = Plug.Test.init_test_session(conn, user_id: user.id)
    conn = authenticate_session(conn, [])
    assert ensure_authenticated(conn, []) == conn
  end

  test "halts connection if not authenticated", %{conn: conn} do
    conn = Plug.Test.init_test_session(conn, user_id: 0)
    conn = authenticate_session(conn, [])
    conn = ensure_authenticated(conn, [])
    assert conn.status == 401
    assert conn.halted
  end

  #
  # Helpers
  #

  defp create_user(context) do
    Map.put(context, :user, User.create!(factory(:user)))
  end
end
