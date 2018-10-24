defmodule GitGud.Web.EmailController do
  @moduledoc """
  Module responsible for CRUD actions on `GitGud.Email`.
  """

  use GitGud.Web, :controller

  alias GitGud.DB
  alias GitGud.Email

  plug :ensure_authenticated
  plug :put_layout, :user_settings

  action_fallback GitGud.Web.FallbackController

  @doc """
  Renders emails.
  """
  @spec index(Plug.Conn.t, map) :: Plug.Conn.t
  def index(conn, _params) do
    user = DB.preload(current_user(conn), :emails)
    changeset = Email.changeset(%Email{})
    render(conn, "index.html", user: user, changeset: changeset)
  end

  @doc """
  Creates a new email.
  """
  @spec create(Plug.Conn.t, map) :: Plug.Conn.t
  def create(conn, %{"email" => key_params} = _params) do
    user = DB.preload(current_user(conn), :emails)
    case Email.create(Map.put(key_params, "user_id", user.id)) do
      {:ok, email} ->
        conn
        |> put_flash(:info, "Email '#{email.email}' added.")
        |> redirect(to: Routes.email_path(conn, :index))
      {:error, changeset} ->
        conn
        |> put_flash(:error, "Something went wrong! Please check error(s) below.")
        |> put_status(:bad_request)
        |> render("index.html", user: user, changeset: %{changeset|action: :insert})
    end
  end
end
