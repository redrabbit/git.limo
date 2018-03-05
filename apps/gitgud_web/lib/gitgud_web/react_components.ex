defmodule GitGud.Web.ReactComponents do
  @moduledoc """
  Functions to make rendering React components.
  """

  import Phoenix.HTML.Tag

  @doc """
  Generate a div containing the named React component with no props or options.
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
  Generate a div containing the named React component and pass it props.
  Returns safe html: `{:safe, [60, "div", ...]}`.
  Props can be passed in as a Map or a List.
  You can utilize this in your Phoenix views:
  ```
  <%= GitGud.Web.React.react_component("MyComponent", %{language: "elixir", awesome: true}) %>
  ```
  The resulting `<div>` tag is formatted specifically for the included javascript
  helper to then turn into your named React component and then pass in the props specified.
  """
  def react_component(name, props) when is_list(props) do
    react_component(name, Enum.into(props, %{}))
  end
  def react_component(name, props) when is_map(props) do
    props = Poison.encode!(props)
    content_tag(:div, "", [{:data, [react_class: name, react_props: props]}])
  end

  @doc """
  Generate a div containing the named React component and pass it props and options.
  Returns safe html: `{:safe, [60, "div", ...]}`.
  For now, props MUST be passed in as a Map. The only option currently accepted is `target_id`.
  If you pass in a `target_id`, the resulting `<div>` tag will tell the javascirpt helper
  which HTML element you'd like to render the React component. This is helpful in scenarios
  like server-side rendering of a component.
  You can utilize this in your Phoenix views:
  ```
  <%= GitGud.Web.React.react_component(
        "MyComponent",
        %{language: "elixir", awesome: true},
        target_id: "react-div"
      ) %>
  ```
  The resulting `<div>` tag is formatted specifically for the included javascript
  helper to then turn into your named React component and then pass in the props specified.
  """
  def react_component(name, props, opts) when is_map(props) do
    props = Poison.encode!(props)
    content_tag(:div, "", [{:data, [react_class: name, react_props: props, react_target_id: opts[:target_id]]}])
  end
end
