defmodule GitGud.Web.SessionController do
  @moduledoc """
  Module responsible for user authentication.
  """

  use GitGud.Web, :controller

  alias GitGud.User

  action_fallback GitGud.Web.FallbackController

  @doc """
  Renders the login page.
  """
  @spec new(Plug.Conn.t, map) :: Plug.Conn.t
  def new(conn, params) do
    render(conn, "new.html", redirect: params["redirect_to"])
  end

  @doc """
  Authenticates user with credentials.
  """
  @spec create(Plug.Conn.t, map) :: Plug.Conn.t
  def create(conn, %{"session" => session_params} = _params) do
    if user = User.check_credentials(session_params["login"], session_params["password"]) do
      conn
      |> put_session(:user_id, user.id)
      |> put_flash(:info, "Logged in.")
      |> redirect(to: session_params["redirect"] || Routes.user_path(conn, :show, user))
    else
      conn
      |> put_flash(:error, "Wrong login credentials")
      |> put_status(:unauthorized)
      |> render("new.html", redirect: session_params["redirect"])
    end
  end

  @doc """
  Deletes user session.
  """
  @spec delete(Plug.Conn.t, map) :: Plug.Conn.t
  def delete(conn, _params) do
    conn
    |> delete_session(:user_id)
    |> put_flash(:info, "Logged out.")
    |> redirect(to: Routes.landing_page_path(conn, :index))
  end
end
