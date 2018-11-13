import Phoenix.HTML.Tag
import Phoenix.HTML, only: [raw: 1]

defimpl Phoenix.Param, for: GitGud.GitTreeEntry do
  def to_param(tree_entry), do: tree_entry.name
end

defimpl Phoenix.HTML.Safe, for: GitGud.GitTreeEntry do
  def to_iodata(tree_entry) do
    Phoenix.HTML.Safe.to_iodata(
      cond do
        tree_entry.type == :tree ->
          [content_tag(:span, content_tag(:i, [], class: "fa fa-folder"), class: "icon"), raw(tree_entry.name)]
        tree_entry.type == :blob ->
          [content_tag(:span, content_tag(:i, [], class: "fa fa-file"), class: "icon"), raw(tree_entry.name)]
        tree_entry.type == :commit ->
          [content_tag(:span, content_tag(:i, [], class: "fa fa-archive"), class: "icon"), raw(tree_entry.name)]
      end
    )
  end
end

