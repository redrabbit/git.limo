defmodule GitGud.Web.NavigationHelpersTest do
  use GitGud.Web.ConnCase, async: true

  import Phoenix.HTML.Safe

  import GitGud.Web.NavigationHelpers

  test "route matches controller and action", %{conn: conn} do
    conn = get(conn, "/user/repo/tree/master/config/config.exs")
    assert current_route?(conn, :codebase)
    assert current_route?(conn, :codebase, :tree)
    assert current_route?(conn, :codebase, only: [:tree, :blob])
    assert current_route?(conn, :codebase, except: [:show, :edit])
  end

  test "route does not match controller and action", %{conn: conn} do
    conn = get(conn, "/settings/ssh/new")
    refute current_route?(conn, :ssh_key, :index)
    refute current_route?(conn, :ssh_key, only: [:create])
    refute current_route?(conn, :ssh_key, except: [:new])
    refute current_route?(conn, :user)
  end

  test "renders active navigation item", %{conn: conn} do
    conn = get(conn, "/")
    html = navigation_item(conn, :landing_page, :index, do: "Here")
    assert to_string(to_iodata(html)) == ~s(<li class="is-active">Here</li>)
  end

  test "renders inactive navigation item", %{conn: conn} do
    conn = get(conn, "/new")
    html = navigation_item(conn, :user, do: "Somewhere else")
    assert to_string(to_iodata(html)) == ~s(<li>Somewhere else</li>)
  end
end

