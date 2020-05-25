defmodule GitGud.Web.IssueView do
  @moduledoc false
  use GitGud.Web, :view

  alias GitGud.Issue
  alias GitGud.IssueQuery

  import Phoenix.Controller, only: [current_path: 2]
  import Phoenix.HTML.Tag
  import Phoenix.HTML.Link

  import GitGud.Web.IssueLabelView, only: [label_button: 2]

  def encode_search_query(params) when is_list(params) do
    params
    |> Enum.flat_map(&map_search_query_param/1)
    |> Enum.join(" ")
  end

  def encode_search_query(q, params \\ []) when is_map(q) do
    q
    |> order_search_query()
    |> Keyword.merge(params)
    |> encode_search_query()
  end


  def status_button(conn, issue, attrs \\ [])
  def status_button(conn, %Issue{status: status} = _issue, attrs), do: status_button(conn, String.to_atom(status), attrs)
  def status_button(conn, :open, attrs) do
    {icon_attrs, attrs} = Keyword.pop(attrs, :icon, [])
    status = if :open in conn.assigns.q.status, do: [:close], else: [:open]
    query = encode_search_query(conn.assigns.q, status: status)
    link(Keyword.merge([to: current_path(conn, %{q: query}), class: "button"], attrs, fn
      :to, _v1, v2 -> v2
      _k, v1, v2 -> "#{v1} #{v2}" end), do: [
      content_tag(:span, content_tag(:i, [], class: "fa fa-exclamation-circle"), Keyword.merge([class: "icon"], icon_attrs, fn _k, v1, v2 -> "#{v1} #{v2}" end)),
      content_tag(:span, "Open")
    ])
  end

  def status_button(conn, :close, attrs) do
    {icon_attrs, attrs} = Keyword.pop(attrs, :icon, [])
    status = if :close in conn.assigns.q.status, do: [:open], else: [:close]
    query = encode_search_query(conn.assigns.q, status: status)
    link(Keyword.merge([to: current_path(conn, %{q: query}), class: "button"], attrs, fn
      :to, _v1, v2 -> v2
      _k, v1, v2 -> "#{v1} #{v2}" end), do: [
      content_tag(:span, content_tag(:i, [], class: "fa fa-check-circle"), Keyword.merge([class: "icon"], icon_attrs, fn _k, v1, v2 -> "#{v1} #{v2}" end)),
      content_tag(:span, "Closed")
    ])
  end

  def status_icon(issue, attrs \\ [])
  def status_icon(%Issue{status: status}, attrs), do: status_icon(String.to_atom(status), attrs)
  def status_icon(:open, attrs) do
      content_tag(:span, content_tag(:i, [], class: "fa fa-exclamation-circle"), Keyword.merge([class: "icon has-text-success"], attrs, fn _k, v1, v2 -> "#{v1} #{v2}" end))
  end


  def status_icon(:close, attrs) do
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
  def title(action, %{repo: repo}) when action in [:new, :create], do: "New issue · #{repo.owner.login}/#{repo.name}"

  #
  # Helpers
  #

  defp map_search_query_param({:status, status}), do: Enum.map(status, &"is:#{quote_str(&1)}")
  defp map_search_query_param({:labels, labels}), do: Enum.map(labels, &"label:#{quote_str(&1)}")
  defp map_search_query_param({:search, search}), do: Enum.map(search, &quote_str/1)

  defp order_search_query(%{status: status, labels: labels, search: search}) do
    [status: status, labels: labels, search: search]
  end

  defp quote_str(str) when not is_binary(str), do: quote_str(to_string(str))
  defp quote_str(str) do
    if String.contains?(str, " "),
     do: "\"#{str}\"",
   else: str
  end
end
