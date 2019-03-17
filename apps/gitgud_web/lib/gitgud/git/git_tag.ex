import Phoenix.HTML.Tag

defimpl Phoenix.Param, for: GitGud.GitTag do
  def to_param(tag), do: tag.name
end

defimpl Phoenix.HTML.Safe, for: GitGud.GitTag do
  def to_iodata(reference) do
    Phoenix.HTML.Safe.to_iodata([content_tag(:span, content_tag(:i, [], class: "fa fa-tag"), class: "icon"), content_tag(:span, reference.name)])
  end
end

