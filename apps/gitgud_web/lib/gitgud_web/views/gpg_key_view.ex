defmodule GitGud.Web.GPGKeyView do
  @moduledoc false
  use GitGud.Web, :view

  @spec title(atom, map) :: binary
  def title(:index, _assigns), do: "GPG keys"
  def title(:new, _assigns), do: "Add a new GPG key"
end
