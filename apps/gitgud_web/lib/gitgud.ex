import Phoenix.HTML, only: [raw: 1]
import Phoenix.HTML.Tag

import GitRekt.Git, only: [oid_fmt: 1, oid_fmt_short: 1]

import GitGud.Web.Gravatar, only: [gravatar: 2]

defimpl Phoenix.HTML.Safe, for: GitGud.User do
  def to_iodata(user) do
    Phoenix.HTML.Safe.to_iodata([gravatar(user, size: 20), raw(user.login)])
  end
end

defimpl Phoenix.Param, for: GitGud.User do
  def to_param(user), do: user.login
end

defimpl Phoenix.Param, for: GitGud.Repo do
  def to_param(repo), do: repo.name
end

defimpl Phoenix.Param, for: GitGud.Commit do
  def to_param(commit), do: oid_fmt(commit.oid)
end

defimpl Phoenix.HTML.Safe, for: GitGud.Commit do
  def to_iodata(commit) do
    Phoenix.HTML.Safe.to_iodata(content_tag(:span, oid_fmt_short(commit.oid), class: "commit"))
  end
end

defimpl Bamboo.Formatter, for: GitGud.Email do
  def format_email_address(email, _opts), do: {email.user.name, email.address}
end
