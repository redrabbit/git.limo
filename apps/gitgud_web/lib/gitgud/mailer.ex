defmodule GitGud.Mailer do
  @moduledoc """
  Conveniences for composing and sending emails.
  """
  use Bamboo.Mailer, otp_app: :gitgud_web
  use Bamboo.Phoenix, view: GitGud.Web.MailerView

  alias GitGud.Email

  @doc """
  Returns a verification mail for the given `email`.
  """
  @spec verification_email(Email.t) :: Bamboo.Email.t
  def verification_email(%Email{} = email) do
    base_email()
    |> to(email)
    |> subject("Verify your email address")
    |> assign(:user, email.user)
    |> assign(:token, Phoenix.Token.sign(GitGud.Web.Endpoint, "verify-email", email.id))
    |> render(:verify_email)
  end

  @doc """
  Returns a password reset mail for the given `email`.
  """
  @spec password_reset_email(Email.t) :: Bamboo.Email.t
  def password_reset_email(%Email{} = email) do
    base_email()
    |> to(email)
    |> subject("Reset your password")
    |> assign(:user, email.user)
    |> assign(:token, Phoenix.Token.sign(GitGud.Web.Endpoint, "reset-password", email.user_id))
    |> render(:reset_password)
  end

  #
  # Helpers
  #

  defp base_email do
    new_email()
    |> from("git.limo <no-reply@git.limo>")
    |> put_html_layout({GitGud.Web.LayoutView, "mailer.html"})
  end
end
