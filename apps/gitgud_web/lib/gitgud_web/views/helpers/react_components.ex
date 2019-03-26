defmodule GitGud.Web.ReactComponents do
  @moduledoc """
  Functions to make rendering React components.
  """

  import Absinthe.Adapter.LanguageConventions, only: [to_external_name: 2]

  import Phoenix.HTML.Tag

  @doc """
  Generates a `:div` containing the named React component with no props or attrs.

  Returns safe html: `{:safe, [60, "div", ...]}`.
  You can utilize this in your Phoenix views:
  ```
  <%= GitGud.Web.React.react_component("MyComponent") %>
  ```
  The resulting `<div>` tag is formatted specifically for the included javascript
  helper to then turn into your named React component.
  """
  def react_component(name), do: react_component(name, %{})

  @doc """
  Generates a `:div` containing the named React component with the given `props`.

  Returns safe html: `{:safe, [60, "div", ...]}`.
  Props can be passed in as a Map or a List.
  You can utilize this in your Phoenix views:
  ```
  <%= GitGud.Web.React.react_component("MyComponent", %{language: "elixir", awesome: true}) %>
  ```
  The resulting `<div>` tag is formatted specifically for the included javascript
  helper to then turn into your named React component and then pass in the `props` specified.
  """
  def react_component(name, props) when is_list(props), do: react_component(name, Map.new(props), [])
  def react_component(name, props) when is_map(props), do: react_component(name, props, [])

  @doc """
  Generates a `:div` containing the named React component with the given `props` and `attrs`.

  Returns safe html: `{:safe, [60, "div", ...]}`.

  You can utilize this in your Phoenix views:
  ```
  <%= GitGud.Web.React.react_component(
        "MyComponent",
        %{language: "elixir", awesome: true},
        class: "my-component"
      ) %>
  ```
  The resulting `<div>` tag is formatted specifically for the included javascript
  helper to then turn into your named React component and then pass in the `props` specified.
  """
  def react_component(name, props, attrs) when is_list(props), do: react_component(name, Map.new(props), attrs)
  def react_component(name, props, attrs) when is_map(props), do: react_component(name, props, attrs, do: "")

  def react_component(name, props, attrs, do: block) when is_list(props), do: react_component(name, Map.new(props), attrs, do: block)
  def react_component(name, props, attrs, do: block) do
    react_attrs = [react_class: name]
    react_attrs = unless Enum.empty?(props), do: Keyword.put(react_attrs, :react_props, Base.encode64(Jason.encode!(transform_case(props)), padding: false)), else: react_attrs
    content_tag(:div, block, [{:data, react_attrs}|attrs])
  end

  #
  # Helpers
  #

  defp transform_case(prop) when is_map(prop) do
    Enum.into(prop, %{}, fn {key, val} ->
      {to_external_name(to_string(key), :variable), transform_case(val)}
    end)
  end

  defp transform_case(prop) when is_list(prop), do: Enum.map(prop, &transform_case/1)
  defp transform_case(prop), do: prop
end
