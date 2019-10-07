defmodule GitGud.Web.IssueView do
  @moduledoc false
  use GitGud.Web, :view

  alias GitGud.Issue
  alias GitGud.IssueQuery

  import Phoenix.HTML.Tag
  import Phoenix.HTML.Link

  def label_button(label) do
    GitGud.Web.IssueLabelView.label_button(label)
  end

  @spec status_tag(Issue.t | binary, keyword) :: binary
  def status_tag(issue, attrs \\ [])
  def status_tag(%Issue{status: status} = _issue, attrs), do: status_tag(status, attrs)
  def status_tag("open", attrs) do
    content_tag(:p, Keyword.merge([class: "tag is-success"], attrs, fn _k, v1, v2 -> "#{v1} #{v2}" end), do: [
      content_tag(:span, content_tag(:i, [], class: "fa fa-exclamation-circle"), class: "icon"),
      content_tag(:span, "Open")
    ])
  end

  def status_tag("close", attrs) do
    content_tag(:p, Keyword.merge([class: "tag is-danger"], attrs, fn _k, v1, v2 -> "#{v1} #{v2}" end), do: [
      content_tag(:span, content_tag(:i, [], class: "fa fa-check-circle"), class: "icon"),
      content_tag(:span, "Closed")
    ])
  end

  def status_button(issue, attrs \\ [])
  def status_button(%Issue{status: status} = _issue, attrs), do: status_button(status, attrs)
  def status_button("open", attrs) do
    {icon_attrs, attrs} = Keyword.pop(attrs, :icon, [])
    link(Keyword.merge([to: "?status=open", class: "button"], attrs, fn
      :to, _v1, v2 -> v2
      _k, v1, v2 -> "#{v1} #{v2}" end), do: [
      content_tag(:span, content_tag(:i, [], class: "fa fa-exclamation-circle"), Keyword.merge([class: "icon"], icon_attrs, fn _k, v1, v2 -> "#{v1} #{v2}" end)),
      content_tag(:span, "Open")
    ])
  end

  def status_button("close", attrs) do
    {icon_attrs, attrs} = Keyword.pop(attrs, :icon, [])
    link(Keyword.merge([to: "?status=close", class: "button"], attrs, fn
      :to, _v1, v2 -> v2
      _k, v1, v2 -> "#{v1} #{v2}" end), do: [
      content_tag(:span, content_tag(:i, [], class: "fa fa-check-circle"), Keyword.merge([class: "icon"], icon_attrs, fn _k, v1, v2 -> "#{v1} #{v2}" end)),
      content_tag(:span, "Closed")
    ])
  end

  def status_icon(issue, attrs \\ [])
  def status_icon(%Issue{status: status}, attrs), do: status_icon(status, attrs)
  def status_icon("open", attrs) do
      content_tag(:span, content_tag(:i, [], class: "fa fa-exclamation-circle"), Keyword.merge([class: "icon has-text-success"], attrs, fn _k, v1, v2 -> "#{v1} #{v2}" end))
  end


  def status_icon("close", attrs) do
      content_tag(:span, content_tag(:i, [], class: "fa fa-check-circle"), Keyword.merge([class: "icon has-text-danger"], attrs, fn _k, v1, v2 -> "#{v1} #{v2}" end))
  end

  def count_issues(repo, status) do
    if Ecto.assoc_loaded?(repo.issues),
     do: Enum.count(filter_issues(repo, status)),
   else: IssueQuery.count_repo_issues(repo, status: status)
  end

  def filter_issues(issues, "all"), do: issues
  def filter_issues(issues, status) do
    Enum.filter(issues, &(&1.status == to_string(status)))
  end

  @spec title(atom, map) :: binary
  def title(:index, %{repo: repo}), do: "Issues · #{repo.owner.login}/#{repo.name}"
  def title(:show, %{repo: repo, issue: issue}), do: "#{issue.title} ##{issue.number} · #{repo.owner.login}/#{repo.name}"
  def title(:new, %{repo: repo}), do: "New issue · #{repo.owner.login}/#{repo.name}"
end
