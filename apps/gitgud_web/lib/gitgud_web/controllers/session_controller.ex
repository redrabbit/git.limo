defmodule GitGud.Web.SessionController do
  @moduledoc """
  Module responsible for user authentication.
  """

  use GitGud.Web, :controller

  alias GitGud.Account

  plug :put_layout, :hero
  plug :ensure_authenticated when action == :delete

  action_fallback GitGud.Web.FallbackController

  @doc """
  Renders the login page.
  """
  @spec new(Plug.Conn.t, map) :: Plug.Conn.t
  def new(conn, params) do
    render(conn, "new.html", changeset: session_changeset(), redirect: params["redirect_to"])
  end

  @doc """
  Authenticates user with credentials.
  """
  @spec create(Plug.Conn.t, map) :: Plug.Conn.t
  def create(conn, %{"session" => session_params} = _params) do
    changeset = session_changeset(session_params)
    if changeset.valid? do
      if user = Account.check_credentials(changeset.params["login_or_email"], changeset.params["password"]) do
        conn
        |> put_session(:user_id, user.id)
        |> put_flash(:info, "Welcome #{user.login}.")
        |> redirect(to: session_params["redirect"] || Routes.user_path(conn, :show, user))
      else
        conn
        |> put_flash(:error, "Wrong login credentials.")
        |> put_status(:unauthorized)
        |> render("new.html", changeset: %{changeset|action: :insert}, redirect: changeset.params["redirect"])
      end
    else
      conn
      |> put_flash(:error, "Something went wrong! Please check error(s) below.")
      |> put_status(:bad_request)
      |> render("new.html", changeset: %{changeset|action: :insert}, redirect: changeset.params["redirect"])
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

  #
  # Helpers
  #

  defp session_changeset(params \\ %{}) do
    types = %{login_or_email: :string, password: :string}
    fields = Map.keys(types)
    {Map.new(), types}
    |> Ecto.Changeset.cast(params, fields)
    |> Ecto.Changeset.validate_required(fields)
  end
end
