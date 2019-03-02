defimpl Bamboo.Formatter, for: GitGud.Email do
  def format_email_address(email, _opts), do: {email.user.name, email.address}
end
