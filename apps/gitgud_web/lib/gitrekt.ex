alias GitRekt.{GitCommit, GitTag, GitRef, GitTreeEntry}

import Phoenix.HTML.Tag

import GitRekt.Git, only: [oid_fmt: 1, oid_fmt_short: 1]

defimpl Phoenix.HTML.Safe, for: GitCommit do
  def to_iodata(%GitCommit{oid: oid}) do
    Phoenix.HTML.Safe.to_iodata([
      content_tag(:span, oid_fmt_short(oid), class: "is-family-monospace")
    ])
  end
end

defimpl Phoenix.HTML.Safe, for: GitTag do
  def to_iodata(%GitTag{name: name}) do
    Phoenix.HTML.Safe.to_iodata([
      content_tag(:span, content_tag(:i, [], class: "fa fa-tag"), class: "icon"),
      content_tag(:span, name)
    ])
  end
end

defimpl Phoenix.HTML.Safe, for: GitRef do
  def to_iodata(%GitRef{name: name, type: type}) do
    Phoenix.HTML.Safe.to_iodata(
      case type do
        :branch -> [content_tag(:span, content_tag(:i, [], class: "fa fa-code-branch"), class: "icon"), content_tag(:span, name)]
        :tag -> [content_tag(:span, content_tag(:i, [], class: "fa fa-tag"), class: "icon"), content_tag(:span, name)]
      end
    )
  end
end

defimpl Phoenix.HTML.Safe, for: GitTreeEntry do
  def to_iodata(%GitTreeEntry{name: name, type: type}) do
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

defimpl Phoenix.Param, for: GitCommit do
  def to_param(%GitCommit{oid: oid}), do: oid_fmt(oid)
end

defimpl Phoenix.Param, for: GitTag do
  def to_param(%GitTag{name: name}), do: name
end

defimpl Phoenix.Param, for: GitRef do
  def to_param(%GitRef{name: name}), do: name
end

defimpl Phoenix.Param, for: GitTreeEntry do
  def to_param(%GitTreeEntry{name: name}), do: name
end
