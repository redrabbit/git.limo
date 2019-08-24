defmodule GitGud.Web.IssueView do
  @moduledoc false
  use GitGud.Web, :view

  alias GitGud.Issue

  import Phoenix.HTML.Tag

  def status_tag(issue, attrs \\ [])
  def status_tag(%Issue{status: "open"} = issue, attrs) do
    content_tag(:p, Keyword.merge([class: "tag is-success"], attrs, fn _k, v1, v2 -> "#{v1} #{v2}" end), do: [
      content_tag(:span, content_tag(:i, [], class: "fa fa-exclamation-circle"), class: "icon"),
      content_tag(:span, "Open")
    ])
  end

  def status_tag(%Issue{status: "close"} = issue, attrs) do
    content_tag(:p, Keyword.merge([class: "tag is-danger"], attrs, fn _k, v1, v2 -> "#{v1} #{v2}" end), do: [
      content_tag(:span, content_tag(:i, [], class: "fa fa-check-circle"), class: "icon"),
      content_tag(:span, "Closed")
    ])
  end

  def status_icon(issue, attrs \\ [])
  def status_icon(%Issue{status: "open"}, attrs) do
      content_tag(:span, content_tag(:i, [], class: "fa fa-exclamation-circle"), Keyword.merge([class: "icon has-text-success"], attrs, fn _k, v1, v2 -> "#{v1} #{v2}" end))
  end

  def status_icon(%Issue{status: "close"}, attrs) do
      content_tag(:span, content_tag(:i, [], class: "fa fa-check-circle"), Keyword.merge([class: "icon has-text-danger"], attrs, fn _k, v1, v2 -> "#{v1} #{v2}" end))
  end

  def status_icon_with_color()

  @spec title(atom, map) :: binary
  def title(:index, %{repo: repo}), do: "Issues · #{repo.owner.login}/#{repo.name}"
  def title(:show, %{repo: repo, issue: issue}), do: "#{issue.title} · #{repo.owner.login}/#{repo.name}"
  def title(:new, %{repo: repo}), do: "New issue · #{repo.owner.login}/#{repo.name}"
end
