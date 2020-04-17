defmodule GitGud.Web.SessionView do
  @moduledoc false
  use GitGud.Web, :view

  @spec title(atom, map) :: binary
  def title(action, _assign) when action in [:new, :create], do: "Login"
end
