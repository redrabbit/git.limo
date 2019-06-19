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
  @spec pagination(map) :: binary
  def pagination(%{previous?: false, next?: false} = _page), do: []
  def pagination(%{previous?: previous?, previous: previous, next?: next?, next: next, current: _current} = page) do
    content_tag(:nav, [class: "pagination is-right", role: "navigation"], do: [
      link("Previous", to: "?p=#{if previous?, do: previous, else: "#"}", class: "pagination-previous", disabled: !previous?),
      link("Next", to: "?p=#{if next?, do: next, else: "#"}", class: "pagination-next", disabled: !next?),
      pagination_list(page)
    ])
  end

  def pagination(%{previous?: previous?, before: before_cursor, next?: next?, after: after_cursor}) do
    content_tag(:nav, [class: "", role: "navigation"], do: [
      link("Previous", to: "?before=#{if previous?, do: before_cursor, else: "#"}", class: "pagination-previous", disabled: !previous?),
      link("Next", to: "?after=#{if next?, do: after_cursor, else: "#"}", class: "pagination-next", disabled: !next?),
    ])
  end

  def pagination(%{previous?: previous?, previous: previous, next?: next?, next: next}) do
    content_tag(:nav, [class: "", role: "navigation"], do: [
      link("Previous", to: "?p=#{if previous?, do: previous, else: "#"}", class: "pagination-previous", disabled: !previous?),
      link("Next", to: "?p=#{if next?, do: next, else: "#"}", class: "pagination-next", disabled: !next?),
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

  defp slice(list, offset, limit) when is_list(list) do
    list
    |> Enum.drop(offset)
    |> Enum.take(limit)
  end

  defp page_params(conn) do
    if page = conn.params["p"],
      do: String.to_integer(page),
    else: 1
  end
end
