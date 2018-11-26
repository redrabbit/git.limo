defmodule GitGud.Mailer do
  @moduledoc """
  Conveniences for composing and sending emails.
  """
  use Bamboo.Mailer, otp_app: :gitgud_web

  alias GitGud.DB
  alias GitGud.Email

  alias GitGud.Web.Router.Helpers, as: Routes

  import Bamboo.Email

  @doc """
  Returns a verification mail for the given `email`.
  """
  @spec verification_email(Email.t) :: Bamboo.Email.t
  def verification_email(%Email{} = email) do
    email = DB.preload(email, :user)
    token = Phoenix.Token.sign(GitGud.Web.Endpoint, to_string(email.user.id), email.id)
    new_email(
      to: email.address,
      from: "postmaster@sandboxd6a455a9552c4d6bb65b310fe7b619e9.mailgun.org",
      subject: "Verify your email",
      text_body: "Hello #{email.user.name}, please verify your email address by clicking this link: #{Routes.email_url(GitGud.Web.Endpoint, :verify, token)}"
    )
  end
end
