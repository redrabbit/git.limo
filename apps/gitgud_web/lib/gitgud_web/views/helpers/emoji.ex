defmodule GitGud.Web.Emoji do
  @moduledoc """
  Conveniences for rendering emojis.
  """

  @external_resource simple_map = Path.join([:code.priv_dir(:gitgud_web), "emoji", "simplemap.json"])

  @doc """
  Renders the emoji codepoints for the given `name`.
  """
  @spec render(binary) :: binary | nil
  def render(name)
  for {name, emoji} <- Jason.decode!(File.read!(simple_map)) do
    def render(unquote(name)), do: unquote(emoji)
  end

  def render(_name), do: nil
end
