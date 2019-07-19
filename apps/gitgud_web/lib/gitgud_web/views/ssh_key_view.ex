defmodule GitGud.Web.SSHKeyView do
  @moduledoc false
  use GitGud.Web, :view

  @spec title(atom, map) :: binary
  def title(:index, _assigns), do: "Settings · SSH keys"
  def title(:new, _assigns), do: "Settings · Add a new SSH key"
end
