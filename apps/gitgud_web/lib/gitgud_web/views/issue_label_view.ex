defmodule GitGud.Web.IssueLabelView do
  @moduledoc false
  use GitGud.Web, :view

  alias GitGud.IssueLabel

  def label_button(tag \\ :button, label, attrs \\ [])
  def label_button(tag, %IssueLabel{color: nil} = _label, attrs) when is_atom(tag) do
    {attr_class, attrs} = Keyword.pop(attrs, :class, "is-active")
    content_tag(tag, "new label", attrs ++ [class: "button issue-label has-text-dark " <> attr_class, style: "background-color: #dddddd"])
  end

  def label_button(tag, %IssueLabel{description: nil} = label, attrs) when is_atom(tag) do
    threshold = 130
    label_text_class = if color_brighness(label.color) > threshold, do: "has-text-dark", else: "has-text-light"
    {attr_class, attrs} = Keyword.pop(attrs, :class, "is-active")
    content_tag(tag, label.name, attrs ++ [class: "button issue-label #{label_text_class} tooltip " <> attr_class, style: "background-color: ##{label.color}"])
  end

  def label_button(tag, %IssueLabel{} = label, attrs) when is_atom(tag) do
    threshold = 130
    label_text_class = if color_brighness(label.color) > threshold, do: "has-text-dark", else: "has-text-light"
    {attr_class, attrs} = Keyword.pop(attrs, :class, "is-active")
    content_tag(tag, label.name, attrs ++ [class: "button issue-label #{label_text_class} tooltip " <> attr_class, style: "background-color: ##{label.color}", data: [tooltip: label.description]])
  end

  def label_button(conn, label, attrs) do
    case conn.assigns do
      %{repo: repo, q: q} ->
        query = GitGud.Web.IssueView.encode_search_query(q, labels: [label.name])
        {href, attrs} = Keyword.pop(attrs, :href, Routes.issue_path(conn, :index, repo.owner, repo, q: query))
        label_button(:a, label, attrs ++ [href: href])
      %{repo: repo} ->
        query = GitGud.Web.IssueView.encode_search_query(labels: [label.name])
        {href, attrs} = Keyword.pop(attrs, :href, Routes.issue_path(conn, :index, repo.owner, repo, q: query))
        label_button(:a, label, attrs ++ [href: href])
    end
  end

  def color_picker(%IssueLabel{color: nil} = _label) do
    content_tag(:a, "#dddddd", class: "button pickr has-text-dark", style: "background-color: #dddddd")
  end

  def color_picker(%IssueLabel{color: color} = _label) do
    threshold = 130
    label_text_class = if color_brighness(color) > threshold, do: "has-text-dark", else: "has-text-light"
    content_tag(:a, "#" <> color, class: "button pickr #{label_text_class}", style: "background-color: ##{color}")
  end

  @spec title(atom, map) :: binary
  def title(_action, %{repo: repo}), do: "Issues labels · #{repo.owner.login}/#{repo.name}"

  #
  # Helpers
  #

  defp color_brighness(<<r::binary-size(2), g::binary-size(2), b::binary-size(2)>>) do
    div((String.to_integer(r, 16) * 299) + (String.to_integer(g, 16) * 587) + (String.to_integer(b, 16) * 114), 1_000)
  end
end
