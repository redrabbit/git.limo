import Phoenix.HTML, only: [raw: 1]

import GitGud.Web.Gravatar, only: [gravatar: 2]
import GitGud.Web.GPGKeyView, only: [format_key_id: 1]

alias GitGud.{User, Repo, Issue, Email, GPGKey}

defimpl Phoenix.HTML.Safe, for: User do
  def to_iodata(user) do
    Phoenix.HTML.Safe.to_iodata([gravatar(user, size: 24), raw(user.login)])
  end
end

defimpl Phoenix.Param, for: User do
  def to_param(user), do: user.login
end

defimpl Phoenix.Param, for: Repo do
  def to_param(repo), do: repo.name
end

defimpl Phoenix.Param, for: Issue do
  def to_param(issue), do: to_string(issue.number)
end

defimpl Phoenix.HTML.Safe, for: GPGKey do
  def to_iodata(gpg_key) do
    format_key_id(gpg_key.key_id)
  end
end

defimpl Bamboo.Formatter, for: Email do
  def format_email_address(email, _opts), do: {email.user.name, email.address}
end
