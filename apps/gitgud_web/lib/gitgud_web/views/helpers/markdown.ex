defmodule GitGud.Web.Markdown do
  @moduledoc """
  Conveniences for rendering Markdown.
  """

  import Phoenix.HTML, only: [raw: 1]

  @doc """
  Renders a Markdown formatted `content` to HTML.
  """
  @spec markdown(binary | nil) :: binary | nil
  def markdown(nil), do: nil
  def markdown(content) do
    case Earmark.as_ast(content) do
      {:ok, ast, _warnings} ->
        ast
        |> transform_ast()
        |> Floki.raw_html()
    end
  end

  def markdown_safe(nil), do: nil
  def markdown_safe(content), do: raw(markdown_safe(content))

  #
  # Helpers
  #

  defp transform_ast(ast) do
    ast
    |> Enum.map(&transform_ast_node/1)
    |> List.flatten()
  end

  defp transform_ast_node({tag, _attrs, _ast} = node) when tag in ["code"], do: node
  defp transform_ast_node({tag, attrs, ast}) do
    {tag, attrs, transform_ast(ast)}
  end

  defp transform_ast_node(content) when is_binary(content) do
    content = Regex.replace(~r/:([a-z0-1\+]+):/, content, &emojify_short_name/2)
    auto_link(content, Regex.scan(~r/#[0-9]+|@[a-zA-Z0-9_-]+|[a-f0-9]{7}/, content, return: :index))
  end

  defp emojify_short_name(match, short_name) do
    if emoji = Exmoji.from_short_name(short_name),
     do: Exmoji.EmojiChar.render(emoji),
   else: match
  end

  defp auto_link(content, []), do: content
  defp auto_link(content, indexes) do
    {content, rest, _offset} =
      Enum.reduce(List.flatten(indexes), {[], content, 0}, fn {idx, len}, {acc, rest, offset} ->
        {head, rest} = String.split_at(rest, idx - offset)
        {link, rest} =
          case String.split_at(rest, len) do
            {"#" <> number, rest} ->
              {{"a", [], ["##{number}"]}, rest} # TODO
            {"@" <> login, rest} ->
              {{"a", [{"class", "has-text-black"}], ["@#{login}"]}, rest} # TODO
            {hash, rest} ->
              {{"a", [], [{"code", [{"class", "has-text-link"}], [hash]}]}, rest} # TODO
          end
        {acc ++ [head, link], rest, idx+len}
      end)
    List.flatten(content, [rest])
  end
end
