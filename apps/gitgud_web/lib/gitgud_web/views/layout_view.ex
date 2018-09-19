defmodule GitGud.Web.LayoutView do
  @moduledoc false
  use GitGud.Web, :view

  import GitGud.Web.Router, only: [__routes__: 0]

  @spec current_route?(Plug.Conn.t, atom) :: boolean
  def current_route?(conn, helper) do
    controller_module(conn) == helper_controller(helper)
  end

  @spec current_route?(Plug.Conn.t, atom, [only: [atom]]) :: boolean
  def current_route?(conn, helper, only: actions) when is_list(actions) do
    current_route?(conn, helper) && action_name(conn) in actions
  end

  @spec current_route?(Plug.Conn.t, atom, [except: [atom]]) :: boolean
  def current_route?(conn, helper, except: actions) when is_list(actions) do
    current_route?(conn, helper) && action_name(conn) not in actions
  end

  @spec current_route?(Plug.Conn.t, atom, atom) :: boolean
  def current_route?(conn, helper, action) do
    current_route?(conn, helper) && action_name(conn) == action
  end

  @spec navigation_item(Plug.Conn.t, atom, keyword | atom, keyword) :: binary
  def navigation_item(conn, helper, action, do: block) do
    attrs = if current_route?(conn, helper, action),
        do: [class: "is-active"],
      else: []
    content_tag(:li, block, attrs)
  end

  @spec render_layout({atom(), binary() | atom()}, map, keyword) :: binary
  def render_layout(layout, assigns, do: content) do
    render(layout, Map.put(assigns, :inner_layout, content))
  end

  @spec title(Plug.Conn.t, binary) :: binary
  def title(conn, default \\ "") do
    try do
      apply(view_module(conn), :title, [action_name(conn), conn.assigns])
    rescue
      _error -> default
    end
  end

  #
  # Helpers
  #

  for route <- Enum.uniq_by(Enum.filter(__routes__(), &is_binary(&1.helper)), &(&1.helper)) do
    helper = String.to_atom(route.helper)
    defp helper_controller(unquote(helper)), do: unquote(route.plug)
  end

  defp helper_controller(helper), do: raise ArgumentError, message: "invalid helper #{inspect helper}"
end
