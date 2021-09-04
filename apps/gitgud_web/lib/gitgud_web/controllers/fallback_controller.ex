defmodule GitGud.Web.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use GitGud.Web, :controller

  def call(conn, {:error, error_status}) when is_atom(error_status) do
    conn
    |> put_layout(false)
    |> put_view(GitGud.Web.ErrorView)
    |> put_status(error_status)
    |> render(String.to_atom(to_string(Plug.Conn.Status.code(error_status))))
  end

  def call(conn, {:error, error_reason}) when is_binary(error_reason) do
    conn
    |> put_layout(false)
    |> put_view(GitGud.Web.ErrorView)
    |> put_status(:internal_server_error)
    |> render(:internal_server_error, error_reason: error_reason)
  end
end
