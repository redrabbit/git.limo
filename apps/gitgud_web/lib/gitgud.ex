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

defimpl Phoenix.HTML.Safe, for: Map do
  def to_iodata(%{type: :commit, oid: oid}) do
    Phoenix.HTML.Safe.to_iodata(content_tag(:span, oid_fmt_short(oid), class: "commit"))
  end

  def to_iodata(%{type: :tag, name: name}) do
    Phoenix.HTML.Safe.to_iodata([content_tag(:span, content_tag(:i, [], class: "fa fa-tag"), class: "icon"), content_tag(:span, name)])
  end

  def to_iodata(%{type: :reference, name: name, subtype: type}) do
    Phoenix.HTML.Safe.to_iodata(
      case type do
        :branch -> [content_tag(:span, content_tag(:i, [], class: "fa fa-code-branch"), class: "icon"), content_tag(:span, name)]
        :tag -> [content_tag(:span, content_tag(:i, [], class: "fa fa-tag"), class: "icon"), content_tag(:span, name)]
      end
    )
  end

  def to_iodata(%{type: :tree_entry, name: name, subtype: type}) do
    Phoenix.HTML.Safe.to_iodata(
      case type do
        :commit ->
          [content_tag(:span, content_tag(:i, [], class: "fa fa-archive"), class: "icon"), content_tag(:span, name)]
        :tree ->
          [content_tag(:span, content_tag(:i, [], class: "fa fa-folder"), class: "icon"), content_tag(:span, name)]
        :blob ->
          [content_tag(:span, content_tag(:i, [], class: "fa fa-file"), class: "icon"), content_tag(:span, name)]
      end
    )
  end
end

defimpl Phoenix.Param, for: Map do
  def to_param(%{type: :commit, oid: oid}), do: oid_fmt(oid)
  def to_param(%{type: :tag, name: name}), do: name
  def to_param(%{type: :reference, name: name}), do: name
  def to_param(%{type: :tree_entry, name: name}), do: name
end

defimpl Bamboo.Formatter, for: GitGud.Email do
  def format_email_address(email, _opts), do: {email.user.name, email.address}
end
