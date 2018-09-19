defmodule GitGud.Web.AuthenticationView do
  @moduledoc false
  use GitGud.Web, :view

  @spec title(atom, map) :: binary
  def title(:new, _assign), do: "Login"
end
