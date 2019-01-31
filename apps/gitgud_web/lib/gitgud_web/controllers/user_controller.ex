defmodule GitGud.Web.UserController do
  @moduledoc """
  Module responsible for CRUD actions on `GitGud.User`.
  """

  use GitGud.Web, :controller

  alias GitGud.DB

  alias GitGud.Auth
  alias GitGud.Email

  alias GitGud.User
  alias GitGud.UserQuery

  @settings_actions [
    :edit_profile,
    :edit_password,
    :update_profile,
    :update_password
  ]

  plug :ensure_authenticated when action in @settings_actions

  plug :put_layout, :hero when action in [:new, :create, :reset_password, :send_password_reset]
  plug :put_layout, :user_profile when action == :show
  plug :put_layout, :user_settings when action in @settings_actions

  plug :scrub_params, "user" when action == :create
  plug :scrub_params, "profile" when action == :update_profile
  plug :scrub_params, "password" when action == :update_password

  action_fallback GitGud.Web.FallbackController

  @doc """
  Renders the registration page.
  """
  @spec new(Plug.Conn.t, map) :: Plug.Conn.t
  def new(conn, _params) do
    render(conn, "new.html", changeset: User.registration_changeset(%User{auth: %Auth{}, emails: [%Email{}]}))
  end

  @doc """
  Creates a new user.
  """
  @spec create(Plug.Conn.t, map) :: Plug.Conn.t
  def create(conn, %{"user" => user_params} = _params) do
    case User.create(user_params) do
      {:ok, user} ->
        for email <- Enum.reject(user.emails, &(&1.verified)), do:
          GitGud.Mailer.deliver_later(GitGud.Mailer.verification_email(email))
        conn
        |> put_session(:user_id, user.id)
        |> put_flash(:info, "Welcome #{user.login}.")
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
  def show(conn, %{"user_name" => user_name} = _params) do
    if user = UserQuery.by_login(user_name, preload: [:primary_email, :public_email, :repos], viewer: current_user(conn)),
      do: render(conn, "show.html", user: user),
    else: {:error, :not_found}
  end

  @doc """
  Renders a profile edit form.
  """
  @spec edit_profile(Plug.Conn.t, map) :: Plug.Conn.t
  def edit_profile(conn, _params) do
    user = DB.preload(current_user(conn), [:public_email, :emails])
    changeset = User.profile_changeset(user)
    render(conn, "edit_profile.html", user: user, changeset: changeset)
  end

  @doc """
  Updates a profile.
  """
  @spec update_profile(Plug.Conn.t, map) :: Plug.Conn.t
  def update_profile(conn, %{"profile" => profile_params} = _params) do
    user = DB.preload(current_user(conn), [:public_email, :emails])
    case User.update(user, :profile, profile_params) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Profile updated.")
        |> redirect(to: Routes.user_path(conn, :edit_profile))
      {:error, changeset} ->
        conn
        |> put_flash(:error, "Something went wrong! Please check error(s) below.")
        |> put_status(:bad_request)
        |> render("edit_profile.html", user: user, changeset: %{changeset|action: :update})
    end
  end

  @doc """
  Renders a password edit form.
  """
  @spec edit_password(Plug.Conn.t, map) :: Plug.Conn.t
  def edit_password(conn, _params) do
    user = DB.preload(current_user(conn), :auth)
    changeset = User.password_changeset(user)
    render(conn, "edit_password.html", user: user, changeset: changeset)
  end

  @doc """
  Updates a password.
  """
  @spec update_password(Plug.Conn.t, map) :: Plug.Conn.t
  def update_password(conn, %{"password" => password_params} = _params) do
    user = DB.preload(current_user(conn), :auth)
    case User.update(user, :password, password_params) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Password updated.")
        |> redirect(to: Routes.user_path(conn, :edit_password))
      {:error, changeset} ->
        conn
        |> put_flash(:error, "Something went wrong! Please check error(s) below.")
        |> put_status(:bad_request)
        |> render("edit_password.html", user: user, changeset: %{changeset|action: :update})
    end
  end

  @spec reset_password(Plug.Conn.t, map) :: Plug.Conn.t
  def reset_password(conn, _params) do
    render(conn, "reset_password.html", changeset: password_reset_changeset())
  end

  @spec send_password_reset(Plug.Conn.t, map) :: Plug.Conn.t
  def send_password_reset(conn, %{"email" => email_params} = _params) do
    changeset = password_reset_changeset(email_params)
    if changeset.valid? do
      email_address = changeset.params["address"]
      if user = UserQuery.by_email(email_address, preload: :emails) do
        if email = Enum.find(user.emails, &(&1.verified && &1.address == email_address)) do
          GitGud.Mailer.deliver_later(GitGud.Mailer.password_reset_email(email))
        end
      end
      conn
      |> put_flash(:info, "A password reset email has been sent to '#{email_address}'.")
      |> redirect(to: Routes.session_path(conn, :new))
    else
      conn
      |> put_flash(:error, "Something went wrong! Please check error(s) below.")
      |> put_status(:bad_request)
      |> render("reset_password.html", changeset: %{changeset|action: :insert})
    end
  end

  @spec verify_password_reset(Plug.Conn.t, map) :: Plug.Conn.t
  def verify_password_reset(conn, %{"token" => token} = _params) do
    case Phoenix.Token.verify(conn, "reset-password", token, max_age: 86400) do
      {:ok, user_id} ->
        if user = UserQuery.by_id(user_id, preload: :auth) do
          User.reset_password!(user)
          conn
          |> put_session(:user_id, user_id)
          |> put_flash(:info, "Password has been reset. Please set a new password below.")
          |> redirect(to: Routes.user_path(conn, :edit_password))
        else
          conn
          |> put_flash(:error, "Invalid password reset user.")
          |> redirect(to: Routes.session_path(conn, :new))
        end
      {:error, :invalid} ->
        conn
        |> put_flash(:error, "Invalid password reset token.")
        |> redirect(to: Routes.session_path(conn, :new))
      {:error, :expired} ->
        conn
        |> put_flash(:error, "Password reset token expired.")
        |> redirect(to: Routes.session_path(conn, :new))
    end
  end

  #
  # Helpers
  #

  defp password_reset_changeset(params \\ %{}) do
    %Email{}
    |> Ecto.Changeset.cast(params, [:address])
    |> Ecto.Changeset.validate_required([:address])
    |> Ecto.Changeset.validate_format(:address, ~r/^([a-zA-Z0-9_\-\.]+)@([a-zA-Z0-9_\-\.]+)\.([a-zA-Z]{2,5})$/)
  end
end
