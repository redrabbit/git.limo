defmodule GitGud.Web.PaginationHelpers do
  @moduledoc """
  Conveniences for list pagination.
  """

  import Phoenix.HTML.Link
  import Phoenix.HTML.Tag

  @doc """
  Paginates the given `stream`.
  """
  @spec paginate(Plug.Conn.t, Stream.t, pos_integer) :: map
  def paginate(conn, stream, limit \\ 20) do
    list = Enum.to_list(stream)
    count = max(trunc(Float.ceil(Enum.count(list) / limit)), 1)
    page = min(max(page_params(conn), 1), count)
    %{current: page, previous?: page > 1, next?: page < count, previous: max(page-1, 1), next: min(page+1, count), first: 1, last: count, slice: slice(list, (page-1)*limit, limit)}
  end

  @doc """
  Paginates the given `stream`.
  """
  @spec paginate_cursor(Plug.Conn.t, Stream.t, (any, binary -> boolean), (any -> binary), pos_integer) :: map
  def paginate_cursor(conn, stream, filter_fn, cursor_fn, limit \\ 20)
  def paginate_cursor(conn, slice, _filter_fn, _cursor_fn, limit) when is_list(slice) do
    page = page_params(conn)
    if length(slice) > limit,
      do: %{slice: Enum.take(slice, limit), previous?: page > 1, next?: true, previous: max(page-1, 1), next: page+1},
    else: %{slice: slice, previous?: page > 1, next?: false, previous: max(page-1, 1), next: page}
  end

  def paginate_cursor(conn, stream, filter_fn, cursor_fn, limit) do
    {slice, previous?, next?} =
      cond do
        cursor = conn.params["before"] ->
          stream = Enum.reverse(Stream.take_while(stream, &!filter_fn.(&1, cursor)))
          stream = Stream.take(stream, limit+1)
          slice = Enum.to_list(stream)
          {Enum.reverse(Enum.take(slice, limit)), Enum.count(slice) > limit, true}
        cursor = conn.params["after"] ->
          stream = Stream.drop(Stream.drop_while(stream, &!filter_fn.(&1, cursor)), 1)
          stream = Stream.take(stream, limit+1)
          slice = Enum.to_list(stream)
          {Enum.take(slice, limit), true, Enum.count(slice) > limit}
        true ->
          stream = Stream.take(stream, limit+1)
          slice = Enum.to_list(stream)
          {Enum.take(slice, limit), false, Enum.count(slice) > limit}
      end

    before_cursor = if previous?, do: cursor_fn.(List.first(slice))
    after_cursor = if next?, do: cursor_fn.(List.last(slice))

    %{slice: slice, previous?: previous?, before: before_cursor, next?: next?, after: after_cursor}
  end

  @doc """
  Renders a pagination widget for the given `page`.
  """
  @spec pagination(Plug.Connt.t, map) :: binary
  def pagination(_conn, %{previous?: false, next?: false} = _page), do: []
  def pagination(conn, %{previous?: previous?, previous: previous, next?: next?, next: next, current: _current} = page) do
    content_tag(:nav, [class: "pagination is-right", role: "navigation"], do: [
      link("Previous", to: query_encode(conn, previous? && previous), class: "pagination-previous", disabled: !previous?),
      link("Next", to: query_encode(conn, next? && next), class: "pagination-next", disabled: !next?),
      pagination_list(conn, page)
    ])
  end

  def pagination(conn, %{previous?: previous?, before: before_cursor, next?: next?, after: after_cursor}) do
    content_tag(:nav, [class: "", role: "navigation"], do: [
      link("Previous", to: query_encode(conn, "before", previous? && before_cursor), class: "pagination-previous", disabled: !previous?),
      link("Next", to: query_encode(conn, "after", next? && after_cursor), class: "pagination-next", disabled: !next?),
    ])
  end

  def pagination(conn, %{previous?: previous?, previous: previous, next?: next?, next: next}) do
    content_tag(:nav, [class: "", role: "navigation"], do: [
      link("Previous", to: query_encode(conn, previous? && previous), class: "pagination-previous", disabled: !previous?),
      link("Next", to: query_encode(conn, next? && next), class: "pagination-next", disabled: !next?),
    ])
  end

  #
  # Helpers
  #

  defp pagination_list(conn, page) do
    content_tag(:ul, [class: "pagination-list"], do: [
      pagination_first(conn, page),
      pagination_previous(conn, page),
      pagination_current(conn, page),
      pagination_next(conn, page),
      pagination_last(conn, page)
    ])
  end

  defp pagination_first(_conn, %{first: first, current: first}), do: []
  defp pagination_first(conn, %{first: first}) do
    content_tag(:li, do: link(first, to: query_encode(conn, first), class: "pagination-link"))
  end

  defp pagination_previous(_conn, %{previous: previous, first: previous}), do: []
  defp pagination_previous(conn, %{previous: previous, first: first, last: last}) do
    i = max(5-(last-previous), 1)
    for p <- max(first+1, previous-i)..previous do
      content_tag(:li, do: link(p, to: query_encode(conn, p), class: "pagination-link"))
    end |> pagination_ellipsis(if last > 7 && previous > 3, do: 0)
  end

  defp pagination_current(_conn, %{current: current}) do
    content_tag(:li, do: content_tag(:a, [class: "pagination-link is-current"], do: current))
  end

  defp pagination_next(_conn, %{next: next, last: next}), do: []
  defp pagination_next(conn, %{next: next, last: last}) do
    i = max(6-next, 1)
    for p <- next..min(last-1, next+i) do
      content_tag(:li, do: link(p, to: query_encode(conn, p), class: "pagination-link"))
    end |> pagination_ellipsis(if last > 7 && last-next > 2, do: i)
  end

  defp pagination_ellipsis(list, nil), do: list
  defp pagination_ellipsis(list, i) do
    List.replace_at(list, i, content_tag(:li, do: content_tag(:span, [class: "pagination-ellipsis"], do: "...")))
  end

  defp pagination_last(_conn, %{last: last, current: last}), do: []
  defp pagination_last(conn, %{last: last}) do
      content_tag(:li, do: link(last, to: query_encode(conn, last), class: "pagination-link"))
  end

  defp slice(list, offset, limit) when is_list(list) do
    list
    |> Enum.drop(offset)
    |> Enum.take(limit)
  end

  defp query_encode(conn, val), do: query_encode(conn, "p", val)
  defp query_encode(conn, key, nil), do: "?" <> URI.encode_query(Map.delete(conn.query_params, key))
  defp query_encode(conn, key, val), do: "?" <> URI.encode_query(Map.put(conn.query_params, key, val))

  defp page_params(conn) do
    if page = conn.params["p"],
      do: String.to_integer(page),
    else: 1
  end
end
