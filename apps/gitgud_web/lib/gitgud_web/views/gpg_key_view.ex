defmodule GitGud.Web.GPGKeyView do
  @moduledoc false
  use GitGud.Web, :view

  @spec format_key_id(binary) :: binary
  def format_key_id(key) do
    key
    |> binary_part(20, -8)
    |> Base.encode16()
    |> String.graphemes()
    |> Enum.chunk_every(4)
    |> Enum.join(":")
  end

  @spec title(atom, map) :: binary
  def title(action, _assigns) when action in [:new, :create], do: "Settings · Add a new GPG key"
  def title(_action, _assigns), do: "Settings · GPG keys"
end
