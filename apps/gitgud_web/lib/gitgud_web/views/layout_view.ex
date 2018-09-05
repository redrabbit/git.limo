defmodule GitGud.Web.LayoutView do
  @moduledoc false
  use GitGud.Web, :view

  @doc """
  Renders the given inner `layout` for the passed `do` block.
  """
  @spec render_layout({atom(), binary() | atom()}, map, keyword) :: binary
  def render_layout(layout, assigns, do: content) do
    render(layout, Map.put(assigns, :inner_layout, content))
  end
end
