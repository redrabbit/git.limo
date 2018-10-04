defmodule GitGud.Web.LandingPageController do
  @moduledoc """
  Module responsible for the landing page.
  """

  use GitGud.Web, :controller

  @spec index(Plug.Conn.t, map) :: Plug.Conn.t
  def index(conn, _params) do
    render(conn, "index.html")
  end
end
