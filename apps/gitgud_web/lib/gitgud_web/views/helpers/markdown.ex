defmodule GitGud.Web.Markdown do
  @moduledoc """
  Conveniences for rendering Markdown.
  """

  alias GitGud.UserQuery
  alias GitGud.IssueQuery

  alias GitGud.Web.Router.Helpers, as: Routes

  alias GitRekt.GitAgent

  import Phoenix.HTML, only: [raw: 1]

  @doc """
  Renders a Markdown formatted `content` to HTML.
  """
  @spec markdown(binary | nil, keyword) :: binary | nil
  def markdown(content, opts \\ [])
  def markdown(nil, _opts), do: nil
  def markdown(content, opts) do
    case Earmark.as_ast(content) do
      {:ok, ast, _warnings} ->
        ast
        |> transform_ast(opts)
        |> Floki.raw_html()
      {:error, ast, _errors} ->
        ast
        |> transform_ast(opts)
        |> Floki.raw_html()
    end
  end

  def markdown_safe(content, opts \\ [])
  def markdown_safe(nil, _opts), do: nil
  def markdown_safe(content, opts), do: raw(markdown(content, opts))

  #
  # Helpers
  #

  defp transform_ast(ast, opts) do
    ast
    |> Enum.map(&transform_ast_node(&1, opts))
    |> List.flatten()
  end

  defp transform_ast_node({tag, _attrs, _ast} = node, _opts) when tag in ["code"], do: node
  defp transform_ast_node({tag, attrs, ast}, opts) do
    {tag, attrs, transform_ast(ast, opts)}
  end

  defp transform_ast_node(content, opts) when is_binary(content) do
    transform_ast_node_text(
      content,
      Regex.scan(~r/\B(#[0-9]+)\b|\B(@[a-zA-Z0-9_-]+)\b|:([a-z0-1\+]+):|\b([a-f0-9]{7})\b/, content, capture: :first, return: :index),
      Keyword.get(opts, :repo)
    )
  end

  defp transform_ast_node_text(content, [], _repo), do: content
  defp transform_ast_node_text(content, indexes, repo) do
    {content, rest, _offset} =
      Enum.reduce(List.flatten(indexes), {[], content, 0}, fn {idx, len}, {acc, rest, offset} ->
        ofs = idx-offset
        <<head::binary-size(ofs), rest::binary>> = rest
        <<match::binary-size(len), rest::binary>> = rest
        link =
          case match do
            "#" <> number ->
              if issue = repo && IssueQuery.repo_issue(repo, String.to_integer(number)), do:
                {"a", [{"href", Routes.issue_path(GitGud.Web.Endpoint, :show, repo.owner, repo, issue)}], ["##{number}"]}
            "@" <> login ->
              if user = UserQuery.by_login(login), do:
                {"a", [{"href", Routes.user_path(GitGud.Web.Endpoint, :show, user)}, {"class", "has-text-black"}], ["@#{login}"]}
            match ->
              cond do
                String.starts_with?(match, ":") && String.ends_with?(match, ":") ->
                  emojify_short_name(match, String.slice(match, 1..-2))
                byte_size(match) == 7 ->
                  if repo do
                    case GitAgent.revision(repo, match) do
                      {:ok, commit, _ref} ->
                        {"a", [{"href", Routes.codebase_path(GitGud.Web.Endpoint, :commit, repo.owner, repo, commit)}], [{"code", [{"class", "has-text-link"}], [match]}]}
                      {:error, _reason} ->
                        nil
                    end
                  end
              end
          end || match
        {acc ++ [head, link], rest, idx+len}
      end)
    List.flatten(content, [rest])
  end

  defp emojify_short_name(match, short_name) do
    if emoji = Exmoji.from_short_name(short_name),
     do: Exmoji.EmojiChar.render(emoji),
   else: match
  end

end
