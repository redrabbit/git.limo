defmodule GitGud.Web.LandingPageControllerTest do
  use GitGud.Web.ConnCase

  test "renders landing page", %{conn: conn} do
    conn = get(conn, landing_page_path(conn, :index))
    assert html_response(conn, 200) =~ ~s(<h1 class="title">Hello</h1>)
  end
end
