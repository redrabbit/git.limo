defmodule GitGud.Web.SSHAuthenticationKeyView do
  @moduledoc false
  use GitGud.Web, :view

  @spec title(atom, map) :: binary
  def title(:index, _assigns), do: "SSH keys"
end
