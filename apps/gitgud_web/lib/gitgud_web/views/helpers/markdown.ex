defmodule GitGud.Web.Markdown do
  @moduledoc """
  Conveniences for rendering Markdown.
  """

  import Phoenix.HTML, only: [raw: 1]

  @doc """
  Renders a Gravatar widget for the given `email`.
  """
  @spec markdown(binary) :: binary
  def markdown(nil), do: ""
  def markdown(content) do
    case Earmark.as_html(content) do
      {:ok, html, []} -> raw(html)
    end
  end
end

