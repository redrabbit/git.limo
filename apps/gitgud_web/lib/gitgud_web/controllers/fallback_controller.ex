defmodule GitGud.Web.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use GitGud.Web, :controller

  require Logger

  alias GitGud.Web.ErrorView

  def call(conn, {:error, :bad_request}) do
    conn
    |> put_status(:bad_request)
    |> put_layout(:app)
    |> put_view(ErrorView)
    |> render(:"400")
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> put_layout(:app)
    |> put_view(ErrorView)
    |> render(:"401")
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_layout(:app)
    |> put_view(ErrorView)
    |> render(:"404")
  end

  def call(conn, val) do
    Logger.warn("Uncaught #{inspect val}")
    conn
    |> put_status(:internal_server_error)
    |> put_layout(:app)
    |> put_view(ErrorView)
    |> render(:"500")
  end
end
