defmodule GitGud.Web.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use GitGud.Web, :controller

  def call(conn, {:error, error}) when is_exception(error) do
    call(conn, {:error, Plug.Exception.status(error)})
  end

  def call(conn, {:error, error_status}) when is_atom(error_status) or is_integer(error_status) do
    status_code = status_code_or_500(error_status)
    conn
    |> put_layout(false)
    |> put_view(GitGud.Web.ErrorView)
    |> put_status(status_code)
    |> render(String.to_atom(to_string(status_code)))
  end

  #
  # Helpers
  #

  defp status_code_or_500(error_status) do
    try do
      Plug.Conn.Status.code(error_status)
    rescue
      _error ->
        500
    end
  end
end
