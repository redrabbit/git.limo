defmodule GitGud.Web.GPGKeyView do
  @moduledoc false
  use GitGud.Web, :view

  def format_key_id(key) do
    key
    |> Base.encode16()
    |> String.graphemes()
    |> Enum.chunk_every(4)
    |> Enum.join(":")
  end

  @spec title(atom, map) :: binary
  def title(:index, _assigns), do: "GPG keys"
  def title(:new, _assigns), do: "Add a new GPG key"
end
