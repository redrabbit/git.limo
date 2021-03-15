defmodule GitGud.Web.LayoutView do
  @moduledoc false
  use GitGud.Web, :view

  @spec render_layout({atom(), binary() | atom()}, map, keyword) :: binary
  def render_layout(layout, assigns, do: content) do
    render(layout, Map.put(assigns, :inner_layout, content))
  end

  @spec render_inner_layout(Plug.Conn.t, map) :: binary
  def render_inner_layout(_conn, assigns) do
    Map.get(assigns, :inner_layout, assigns.inner_content)
  end

  @spec session_params(Plug.Conn.t) :: keyword
  def session_params(conn) do
    cond do
      current_route?(conn, :landing_page) -> []
      current_route?(conn, :session) -> []
      current_route?(conn, :user, :new) -> []
      true -> [redirect_to: conn.request_path]
    end
  end

  @spec title(Plug.Conn.t, binary) :: binary
  def title(conn, default \\ ""), do: conn.assigns[:page_title] || view_title(conn) || default

  #
  # Helpers
  #

  defp view_title(conn) do
    try do
      apply(view_module(conn), :title, [action_name(conn), conn.assigns])
    rescue
      _error ->
        nil
    end
  end
end
