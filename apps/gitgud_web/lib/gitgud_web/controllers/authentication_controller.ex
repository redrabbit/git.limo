defmodule GitGud.Web.AuthenticationController do
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
  def new(conn, _params) do
    render(conn, "login.html")
  end

  @doc """
  Authenticates user with credentials.
  """
  @spec create(Plug.Conn.t, map) :: Plug.Conn.t
  def create(conn, %{"credentials" => cred_params} = _params) do
    if user = User.check_credentials(cred_params["email_or_username"], cred_params["password"]) do
      conn
      |> put_session(:user_id, user.id)
      |> put_flash(:info, "Logged in.")
      |> redirect(to: user_profile_path(conn, :show, user))
    else
      conn
      |> put_flash(:error, "Wrong login credentials")
      |> render("login.html")
    end
  end

  @doc """
  Deletes user session.
  """
  @spec delete(Plug.Conn.t, map) :: Plug.Conn.t
  def delete(conn, _params) do
    conn
    |> delete_session(:user_id)
    |> put_flash(:info, "Logged out")
    |> redirect(to: "/login")
  end
end
