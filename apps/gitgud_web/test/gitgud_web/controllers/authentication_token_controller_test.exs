defmodule GitGud.Web.AuthenticationTokenControllerTest do
  use GitGud.Web.ConnCase

  alias GitGud.User
  alias GitGud.Web.AuthenticationPlug

  setup %{conn: conn} do
    user = User.register!(name: "Mario Flach", username: "redrabbit", email: "m.flach@almightycouch.com", password: "test1234")
    conn = put_req_header(conn, "accept", "application/json")
    {:ok, conn: conn, user: user}
  end

  test "authenticate with valid token", %{conn: conn, user: user} do
    conn = put_token(conn, user.id)
    conn = authenticate(conn)
    assert AuthenticationPlug.authenticated?(conn)
  end

  test "fails to authenticate with invalid token", %{conn: conn} do
    token = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
    conn = put_req_header(conn, "authorization", "Bearer #{token}")
    conn = authenticate(conn)
    refute AuthenticationPlug.authenticated?(conn)
  end

  #
  # Helpers
  #

  defp authenticate(conn) do
  conn
  |> bypass_through()
  |> AuthenticationPlug.call(AuthenticationPlug.init([]))
  end

  defp put_token(conn, user_id) do
    token = AuthenticationPlug.generate_token(user_id)
    put_req_header(conn, "authorization", "Bearer #{token}")
  end
end
