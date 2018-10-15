defmodule GitGud.Web.ReactComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.HTML.Safe

  import GitGud.Web.ReactComponents

  test "renders react component without props" do
    component = react_component("Calendar")
    assert to_string(to_iodata(component)) == ~s(<div data-react-class="Calendar" data-react-props="{}"></div>)
  end

  test "renders react component with props" do
    component = react_component("TodoList", %{count: 1, items: ["Buy the Milk"]})
    assert to_string(to_iodata(component)) == ~s(<div data-react-class="TodoList" data-react-props="{&quot;items&quot;:[&quot;Buy the Milk&quot;],&quot;count&quot;:1}"></div>)
  end

  test "renders react component with props and attrs" do
    component = react_component("CountrySelect", %{country_code: "FR"}, class: "select-box")
    assert to_string(to_iodata(component)) == ~s(<div class="select-box" data-react-class="CountrySelect" data-react-props="{&quot;countryCode&quot;:&quot;FR&quot;}"></div>)
  end
end
