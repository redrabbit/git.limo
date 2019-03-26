defmodule GitGud.Web.EmailController do
  @moduledoc """
  Module responsible for CRUD actions on `GitGud.Email`.
  """

  use GitGud.Web, :controller

  alias GitGud.DB

  alias GitGud.Email
  alias GitGud.User

  plug :ensure_authenticated
  plug :put_layout, :user_settings

  action_fallback GitGud.Web.FallbackController

  @doc """
  Renders emails address.
  """
  @spec edit(Plug.Conn.t, map) :: Plug.Conn.t
  def edit(conn, _params) do
    user = DB.preload(current_user(conn), :emails)
    changeset = Email.registration_changeset(%Email{})
    render(conn, "edit.html", user: user, changeset: changeset)
  end

  @doc """
  Creates a new email address.
  """
  @spec create(Plug.Conn.t, map) :: Plug.Conn.t
  def create(conn, %{"email" => email_params} = _params) do
    user = DB.preload(current_user(conn), :emails)
    case Email.create(Map.put(email_params, "user_id", user.id)) do
      {:ok, email} ->
        email = struct(email, user: user)
        GitGud.Mailer.deliver_later(GitGud.Mailer.verification_email(email))
        conn
        |> put_flash(:info, "Email '#{email.address}' added.")
        |> redirect(to: Routes.email_path(conn, :edit))
      {:error, changeset} ->
        conn
        |> put_status(:bad_request)
        |> put_flash(:error, "Something went wrong! Please check error(s) below.")
        |> render("edit.html", user: user, changeset: %{changeset|action: :insert})
    end
  end

  @doc """
  Updates an email address.
  """
  @spec update(Plug.Conn.t, map) :: Plug.Conn.t
  def update(conn, %{"primary_email" => email_params} = _params) do
    user = DB.preload(current_user(conn), [:emails])
    email_id = String.to_integer(email_params["id"])
    if email = Enum.find(user.emails, &(&1.id == email_id)) do
      if email_id != user.primary_email_id do
        User.update!(user, :primary_email, email)
        conn
        |> put_flash(:info, "Email '#{email.address}' is now your primary email.")
        |> redirect(to: Routes.email_path(conn, :edit))
      else
        conn
        |> put_flash(:info, "Email '#{email.address}' is already your primary email.")
        |> redirect(to: Routes.email_path(conn, :edit))
      end
    else
      {:error, :bad_request}
    end
  end

  @doc """
  Deletes an email address.
  """
  @spec delete(Plug.Conn.t, map) :: Plug.Conn.t
  def delete(conn, %{"email" => email_params} = _params) do
    user = DB.preload(current_user(conn), :emails)
    email_id = String.to_integer(email_params["id"])
    if email = Enum.find(user.emails, &(&1.id == email_id)) do
      Email.delete!(email)
      conn
      |> put_flash(:info, "Email '#{email.address}' deleted.")
      |> redirect(to: Routes.email_path(conn, :edit))
    else
      {:error, :bad_request}
    end
  end

  @doc """
  Sends a verification email.
  """
  @spec send_verification(Plug.Conn.t, map) :: Plug.Conn.t
  def send_verification(conn, %{"email" => email_params} = _params) do
    user = DB.preload(current_user(conn), :emails)
    email_id = String.to_integer(email_params["id"])
    if email = Enum.find(user.emails, &(&1.id == email_id)) do
      email = struct(email, user: user)
      GitGud.Mailer.deliver_later(GitGud.Mailer.verification_email(email))
      conn
      |> put_flash(:info, "A verification email has been sent to '#{email.address}'.")
      |> redirect(to: Routes.email_path(conn, :edit))
    else
      {:error, :bad_request}
    end
  end

  @doc """
  Verifies an email address using a bearer token.
  """
  @spec verify(Plug.Conn.t, map) :: Plug.Conn.t
  def verify(conn, %{"token" => token} = _params) do
    user = DB.preload(current_user(conn), :emails)
    case Phoenix.Token.verify(conn, "verify-email", token, max_age: 86400) do
      {:ok, email_id} ->
        if email = Enum.find(user.emails, &(&1.id == email_id)) do
          unless email.verified do
            Email.verify!(email)
            conn
            |> put_flash(:info, "Email '#{email.address}' verified.")
            |> redirect(to: Routes.email_path(conn, :edit))
          else
            conn
            |> put_flash(:info, "Email '#{email.address}' already verified.")
            |> redirect(to: Routes.email_path(conn, :edit))
          end
        else
          conn
          |> put_status(:bad_request)
          |> put_flash(:error, "Invalid verification email.")
          |> render("edit.html", user: user, changeset: Email.registration_changeset(%Email{}))
        end
      {:error, :invalid} ->
        conn
        |> put_status(:bad_request)
        |> put_flash(:error, "Invalid verification token.")
        |> render("edit.html", user: user, changeset: Email.registration_changeset(%Email{}))
      {:error, :expired} ->
        conn
        |> put_status(:bad_request)
        |> put_flash(:error, "Verification token expired.")
        |> render("edit.html", user: user, changeset: Email.registration_changeset(%Email{}))
    end
  end
end
