defmodule GitGud.Web.PaginationHelpersTest do
  use GitGud.Web.ConnCase, async: true

  import Phoenix.HTML.Safe

  import GitGud.Web.PaginationHelpers

  test "paginates list of items from first page", %{conn: conn} do
    conn = get(conn, "/user/repo/history")
    list = Enum.to_list(1..100)
    page = paginate(conn, list, 10)
    assert page.current == 1
    refute page.previous?
    assert page.next?
    assert page.next == 2
    assert page.last == 10
    assert Enum.count(page.slice) == 10
  end

  test "paginates list of items from third page", %{conn: conn} do
    conn = get(conn, "/user/repo/history?p=3")
    list = Enum.to_list(1..100)
    page = paginate(conn, list, 10)
    assert page.current == 3
    assert page.previous?
    assert page.previous == 2
    assert page.next?
    assert page.next == 4
    assert page.last == 10
    assert Enum.count(page.slice) == 10
  end

  test "paginates list of items from last page", %{conn: conn} do
    conn = get(conn, "/user/repo/history?p=10")
    list = Enum.to_list(1..100)
    page = paginate(conn, list, 10)
    assert page.current == 10
    assert page.previous?
    assert page.previous == 9
    refute page.next?
    assert page.last == 10
    assert Enum.count(page.slice) == 10
  end

  test "renders a pagination width for a list of items", %{conn: conn} do
    conn = get(conn, "/user/repo/tags?p=2")
    list = Enum.to_list(1..30)
    page = paginate(conn, list, 10)
    html = pagination(conn, page)
    assert to_string(to_iodata(html)) == ~s(<nav class="pagination is-right" role="navigation"><a class="pagination-previous" href="?p=1">Previous</a><a class="pagination-next" href="?p=3">Next</a><ul class="pagination-list"><li><a class="pagination-link" href="?p=1">1</a></li><li><a class="pagination-link is-current">2</a></li><li><a class="pagination-link" href="?p=3">3</a></li></ul></nav>)
  end
end

