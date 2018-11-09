import Phoenix.HTML.Tag

defimpl Phoenix.Param, for: GitGud.GitReference do
  def to_param(ref), do: ref.name
end

defimpl Phoenix.HTML.Safe, for: GitGud.GitReference do
  def to_iodata(reference) do
    Phoenix.HTML.Safe.to_iodata(
      case GitGud.GitReference.type(reference) do
        {:ok, :branch} ->
          [content_tag(:span, content_tag(:i, [], class: "fa fa-code-branch"), class: "icon"), content_tag(:span, reference.name)]
        {:ok, :tag} ->
          [content_tag(:span, content_tag(:i, [], class: "fa fa-tag"), class: "icon"), content_tag(:span, reference.name)]
      end
    )
  end
end

