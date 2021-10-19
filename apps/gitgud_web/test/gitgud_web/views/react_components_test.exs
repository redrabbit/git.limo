defmodule GitGud.Web.ReactComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.HTML.Safe

  import GitGud.Web.ReactComponents

  test "renders react component without props" do
    component = react_component("Calendar")
    html = Floki.parse_fragment!(to_iodata(component))
    assert Floki.attribute(html, "data-react-class") == ["Calendar"]
  end

  test "renders react component with props" do
    component = react_component("TodoList", %{count: 1, items: ["Buy the Milk"]})
    html = Floki.parse_fragment!(to_iodata(component))
    assert Floki.attribute(html, "data-react-class") == ["TodoList"]
    assert Floki.attribute(html, "data-react-props") == ["eyJjb3VudCI6MSwiaXRlbXMiOlsiQnV5IHRoZSBNaWxrIl19"]
  end

  test "renders react component with props and attrs" do
    component = react_component("CountrySelect", %{country_code: "FR"}, class: "select-box")
    html = Floki.parse_fragment!(to_iodata(component))
    assert Floki.attribute(html, "data-react-class") == ["CountrySelect"]
    assert Floki.attribute(html, "data-react-props") == ["eyJjb3VudHJ5Q29kZSI6IkZSIn0"]
    assert Floki.attribute(html, "class") == ["select-box"]
  end
end
