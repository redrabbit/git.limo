defmodule GitGud.Web.NavigationHelpers do
  @moduledoc """
  Conveniences for routing and navigation.
  """

  import Phoenix.HTML.Tag

  import GitGud.Web.Router, only: [__routes__: 0]

  @doc """
  Returns the `conn` *controller* and *action*  as tuple.
  """
  @spec current_route(Plug.Conn.t) :: {atom, atom}
  def current_route(conn) do
    {helper_name(controller_module(conn)), action_name(conn)}
  end

  @doc """
  Returns `true` if `conn` matches the given route `helper`; otherwhise return `false`.
  """
  @spec current_route?(Plug.Conn.t, atom, []) :: boolean
  def current_route?(conn, helper, action \\ [])
  def current_route?(conn, helper, []) do
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
  def current_route?(conn, helper, action) when is_atom(action) do
    current_route?(conn, helper) && action_name(conn) == action
  end

  @doc """
  Renders a navigation item for the given `helper` and `action`.
  """
  @spec navigation_item(Plug.Conn.t, atom, keyword | atom, atom, keyword, [do: term]) :: binary
  def navigation_item(conn, helper, action \\ [], tag \\ :li, attrs \\ [], [do: block]) do
    class = "is-active"
    attrs = if current_route?(conn, helper, action),
      do: Keyword.update(attrs, :class, class, &("#{&1} #{class}")),
    else: attrs
    content_tag(tag, block, attrs)
  end

  #
  # Helpers
  #

  defp controller_module(conn) do
    conn.assigns[:live_module] || conn.private[:phoenix_controller]
  end

  defp action_name(conn) do
    conn.assigns[:live_action] || conn.private[:phoenix_action]
  end

  for route <- Enum.uniq_by(Enum.filter(__routes__(), &is_binary(&1.helper)), &(&1.plug == Phoenix.LiveView.Plug && elem(&1.private.phoenix_live_view, 0) || &1.plug)) do
    if route.plug == Phoenix.LiveView.Plug do
      {live_module, _opts} = route.private.phoenix_live_view
      with helper <- Module.split(live_module),
           ["GitGud"|helper] <- helper,
           ["Web"|helper] <- helper,
           helper <- Enum.map(helper, &Macro.underscore/1),
           helper <- Enum.join(helper, "_"),
           helper <- String.to_atom(helper) do
        defp helper_controller(unquote(helper)), do: unquote(live_module)
        defp helper_name(unquote(live_module)), do: unquote(helper)
      end
    else
      helper = String.to_atom(route.helper)
      defp helper_controller(unquote(helper)), do: unquote(route.plug)
      defp helper_name(unquote(route.plug)), do: unquote(helper)
    end
  end

  defp helper_controller(helper), do: raise ArgumentError, message: "invalid helper #{inspect helper}"
  defp helper_name(controller), do: raise ArgumentError, message: "invalid controller #{inspect controller}"
end
