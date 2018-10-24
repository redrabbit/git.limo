defmodule GitGud.Web.UserController do
  @moduledoc """
  Module responsible for CRUD actions on `GitGud.User`.
  """

  use GitGud.Web, :controller

  alias GitGud.User
  alias GitGud.Email
  alias GitGud.UserQuery

  plug :ensure_authenticated when action in [:edit, :update]
  plug :put_layout, :user_profile when action == :show
  plug :put_layout, :user_settings when action in [:edit, :update]

  action_fallback GitGud.Web.FallbackController

  @doc """
  Renders the registration page.
  """
  @spec new(Plug.Conn.t, map) :: Plug.Conn.t
  def new(conn, _params) do
    changeset = User.registration_changeset(%User{emails: [Email.changeset(%Email{})]})
    render(conn, "new.html", changeset: changeset)
  end

  @doc """
  Creates a new user.
  """
  @spec create(Plug.Conn.t, map) :: Plug.Conn.t
  def create(conn, %{"user" => user_params} = _params) do
    case User.create(user_params) do
      {:ok, user} ->
        GitGud.Mailer.deliver_later(GitGud.Mailer.verification_email(hd(user.emails)))
        conn
        |> put_session(:user_id, user.id)
        |> put_flash(:info, "Welcome!")
        |> redirect(to: Routes.user_path(conn, :show, user))
      {:error, changeset} ->
        conn
        |> put_flash(:error, "Something went wrong! Please check error(s) below.")
        |> put_status(:bad_request)
        |> render("new.html", changeset: %{changeset|action: :insert})
    end
  end

  @doc """
  Renders a user.
  """
  @spec show(Plug.Conn.t, map) :: Plug.Conn.t
  def show(conn, %{"username" => username} = _params) do
    if user = UserQuery.by_username(username, preload: :repos, viewer: current_user(conn)),
      do: render(conn, "show.html", user: user),
    else: {:error, :not_found}
  end

  @doc """
  Renders a user edit form.
  """
  @spec edit(Plug.Conn.t, map) :: Plug.Conn.t
  def edit(conn, _params) do
    user = current_user(conn)
    changeset = User.profile_changeset(user)
    render(conn, "edit.html", user: user, changeset: changeset)
  end

  @doc """
  Updates a user.
  """
  @spec update(Plug.Conn.t, map) :: Plug.Conn.t
  def update(conn, %{"profile" => profile_params} = _params) do
    user = current_user(conn)
    case User.update(user, :profile, profile_params) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Profile updated.")
        |> redirect(to: Routes.user_path(conn, :edit))
      {:error, changeset} ->
        conn
        |> put_flash(:error, "Something went wrong! Please check error(s) below.")
        |> put_status(:bad_request)
        |> render("edit.html", user: user, changeset: %{changeset|action: :insert})
    end
  end
end
