defmodule GitGud.Web.ErrorViewTest do
  use GitGud.Web.ConnCase, async: true

  import Phoenix.View

  test "renders 401.html" do
    assert render(GitGud.Web.ErrorView, "401.html", []) == "Unauthorized"
  end

  test "renders 404.html" do
    assert render(GitGud.Web.ErrorView, "404.html", []) == "Page not found"
  end

  test "renders 500.html" do
    assert render(GitGud.Web.ErrorView, "500.html", []) == "Internal server error"
  end

  test "renders any other" do
    assert render(GitGud.Web.ErrorView, "505.html", []) == "Internal server error"
  end
end
