defmodule GitGud.Web.RegistrationView do
  @moduledoc false
  use GitGud.Web, :view

  @spec title(atom, map) :: binary
  def title(:new, _assigns), do: "Register"
end

