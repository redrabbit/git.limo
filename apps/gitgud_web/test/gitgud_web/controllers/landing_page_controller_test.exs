defmodule GitGud.Web.LandingPageControllerTest do
  use GitGud.Web.ConnCase, async: true

  alias GitGud.Web.LayoutView

  test "renders landing page", %{conn: conn} do
    conn = get(conn, Routes.landing_page_path(conn, :index))
    assert {:ok, html} = Floki.parse_document(html_response(conn, 200))
    assert Floki.text(Floki.find(html, "title")) == LayoutView.title(conn)
  end
end
