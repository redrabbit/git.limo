defmodule GitGud.Web.UserController do
  @moduledoc """
  Module responsible for CRUD actions on `GitGud.User`.
  """

  use GitGud.Web, :controller

  alias GitGud.User
  alias GitGud.UserQuery

  plug :put_layout, :user_profile_layout when action == :show

  action_fallback GitGud.Web.FallbackController

  @doc """
  Renders the registration page.
  """
  @spec new(Plug.Conn.t, map) :: Plug.Conn.t
  def new(conn, _params) do
    changeset = User.registration_changeset()
    render(conn, "new.html", changeset: changeset)
  end

  @doc """
  Creates a new user.
  """
  @spec create(Plug.Conn.t, map) :: Plug.Conn.t
  def create(conn, %{"user" => user_params} = _params) do
    case User.register(user_params) do
      {:ok, user} ->
        conn
        |> put_session(:user_id, user.id)
        |> put_flash(:info, "Welcome!")
        |> redirect(to: user_path(conn, :show, user))
      {:error, changeset} ->
        conn
        |> put_flash(:error, "Something went wrong! Please check error(s) below.")
        |> render("new.html", changeset: %{changeset|action: :insert})
    end
  end

  @doc """
  Renders a user profile.
  """
  @spec show(Plug.Conn.t, map) :: Plug.Conn.t
  def show(conn, %{"username" => username} = _params) do
    if user = UserQuery.by_username(username, preload: :repositories, viewer: current_user(conn)),
      do: render(conn, "show.html", user: user),
    else: {:error, :not_found}
  end
end

