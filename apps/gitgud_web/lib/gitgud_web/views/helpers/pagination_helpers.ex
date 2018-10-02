defmodule GitGud.Web.PaginationHelpers do
  @moduledoc """
  Conveniences for list pagination.
  """

  import Phoenix.HTML.Link
  import Phoenix.HTML.Tag

  @doc """
  Paginates the given `stream` with the given per-page `limit`.
  """
  @spec paginate(Plug.Conn.t, Enumerable.t, pos_integer) :: map
  def paginate(conn, list, limit \\ 20) do
    count = trunc(Float.ceil(count(list) / limit))
    page = min(max(page_params(conn), 1), count)
    %{current: page, has_previous?: page > 1, has_next?: page < count, previous: max(page-1, 1), next: min(page+1, count), first: 1, last: count, slice: slice(list, (page-1)*limit, limit)}
  end

  @doc """
  Returns a pagination `<nav>`  for the given `page`.
  """
  @spec pagination(map) :: binary
  def pagination(%{first: first, last: first} = _page), do: []
  def pagination(page) do
    content_tag(:nav, [class: "pagination", role: "navigation"], do: [
      link("Previous", to: "?p=#{page.previous}", class: "pagination-previous", disabled: !page.has_previous?),
      link("Next", to: "?p=#{page.next}", class: "pagination-next", disabled: !page.has_next?),
      pagination_list(page)
    ])
  end

  #
  # Helpers
  #

  defp pagination_list(page) do
    content_tag(:ul, [class: "pagination-list"], do: [
      pagination_first(page),
      pagination_previous(page),
      pagination_current(page),
      pagination_next(page),
      pagination_last(page)
    ])
  end

  defp pagination_first(%{first: first, current: first}), do: []
  defp pagination_first(%{first: first}) do
    content_tag(:li, do: link(first, to: "?p=#{first}", class: "pagination-link"))
  end

  defp pagination_previous(%{previous: previous, first: previous}), do: []
  defp pagination_previous(%{previous: previous, first: first, last: last}) do
    i = max(5-(last-previous), 1)
    for p <- max(first+1, previous-i)..previous do
      content_tag(:li, do: link(p, to: "?p=#{p}", class: "pagination-link"))
    end |> pagination_ellipsis(if last > 7 && previous > 3, do: 0)
  end

  defp pagination_current(%{current: current}) do
    content_tag(:li, do: content_tag(:a, [class: "pagination-link is-current"], do: current))
  end

  defp pagination_next(%{next: next, last: next}), do: []
  defp pagination_next(%{next: next, last: last}) do
    i = max(6-next, 1)
    for p <- next..min(last-1, next+i) do
      content_tag(:li, do: link(p, to: "?p=#{p}", class: "pagination-link"))
    end |> pagination_ellipsis(if last > 7 && last-next > 2, do: i)
  end

  defp pagination_ellipsis(list, nil), do: list
  defp pagination_ellipsis(list, i) do
    List.replace_at(list, i, content_tag(:li, do: content_tag(:span, [class: "pagination-ellipsis"], do: "...")))
  end

  defp pagination_last(%{last: last, current: last}), do: []
  defp pagination_last(%{last: last}) do
      content_tag(:li, do: link(last, to: "?p=#{last}", class: "pagination-link"))
  end

  defp count(list) when is_list(list), do: Enum.count(list)
  defp count(stream), do: Enum.count(stream.enum)

  defp slice(list, offset, limit) when is_list(list) do
    list
    |> Enum.drop(offset)
    |> Enum.take(limit)
  end

  defp slice(stream, offset, limit) do
    stream
    |> Stream.drop(offset)
    |> Stream.take(limit)
  end

  defp page_params(conn) do
    if page = conn.params["p"],
      do: String.to_integer(page),
    else: 1
  end
end
