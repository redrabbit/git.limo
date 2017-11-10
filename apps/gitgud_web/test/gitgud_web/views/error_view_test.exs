defmodule GitGud.Web.ErrorViewTest do
  use GitGud.Web.ConnCase, async: true

  import Phoenix.View

  test "renders 400.json" do
    assert render(GitGud.Web.ErrorView, "400.json", []) == %{errors: %{details: "Bad request"}}
    assert render(GitGud.Web.ErrorView, "400.json", details: "Something went wrong.") == %{errors: %{details: "Something went wrong."}}
  end

  test "renders 401.json" do
    assert render(GitGud.Web.ErrorView, "401.json", []) == %{errors: %{details: "Unauthorized"}}
  end

  test "renders 404.json" do
    assert render(GitGud.Web.ErrorView, "404.json", []) == %{errors: %{details: "Page not found"}}
  end

  test "render 500.json" do
    assert render(GitGud.Web.ErrorView, "500.json", []) == %{errors: %{details: "Internal server error"}}
  end

  test "render any other" do
    assert render(GitGud.Web.ErrorView, "505.json", []) == %{errors: %{details: "Internal server error"}}
  end
end
