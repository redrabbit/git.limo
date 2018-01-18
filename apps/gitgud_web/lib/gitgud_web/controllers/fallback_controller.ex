defmodule GitGud.Web.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use GitGud.Web, :controller

  require Logger

  alias GitGud.Web.ErrorView

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> render(ErrorView, :"401")
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> render(ErrorView, :"404")
  end

  def call(conn, val) do
    Logger.warn("Uncaught #{inspect val}")
    conn
    |> put_status(:internal_server_error)
    |> render(ErrorView, :"500")
  end
end
