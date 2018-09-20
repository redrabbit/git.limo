defmodule GitGud.Web.NavigationHelpers do
  @moduledoc """
  Conveniences for routing and navigation.
  """

  import Phoenix.HTML.Tag
  import Phoenix.Controller, only: [controller_module: 1, action_name: 1]

  import GitGud.Web.Router, only: [__routes__: 0]

  @doc """
  Returns `true` if `conn` matches the given route `helper`; otherwhise return `false`.
  """
  @spec current_route?(Plug.Conn.t, atom) :: boolean
  def current_route?(conn, helper) do
    controller_module(conn) == helper_controller(helper)
  end

  @doc """
  Returns `true` if `conn` matches the given route `helper` and `actions`; otherwhise return `false`.
  """
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

  @doc """
  Generates a `:li` navigation item for the given `helper`.
  """
  @spec navigation_item(Plug.Conn.t, atom, keyword) :: binary
  def navigation_item(conn, helper, [do: block] = _do) do
    attrs = if current_route?(conn, helper),
        do: [class: "is-active"],
      else: []
    content_tag(:li, block, attrs)
  end

  @doc """
  Generates a `:li` navigation item for the given `helper` and `action`.
  """
  @spec navigation_item(Plug.Conn.t, atom, keyword | atom, keyword) :: binary
  def navigation_item(conn, helper, action, [do: block] = _do) do
    attrs = if current_route?(conn, helper, action),
        do: [class: "is-active"],
      else: []
    content_tag(:li, block, attrs)
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
