defmodule GitGud.Web.SSHKeyView do
  @moduledoc false
  use GitGud.Web, :view

  @spec title(atom, map) :: binary
  def title(:index, _assigns), do: "SSH keys"
  def title(:new, _assigns), do: "Add a new SSH key"
end
