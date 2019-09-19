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
    auto_link(
      Regex.replace(~r/:([a-z0-1\+]+):/, content, &emojify_short_name/2),
      Regex.scan(~r/\B(#[0-9]+)\b|\B(@[a-zA-Z0-9_-]+)\b|\b([a-f0-9]{7})\b/, content, capture: :first, return: :index),
      Keyword.get(opts, :repo)
    )
  end

  defp emojify_short_name(match, short_name) do
    if emoji = Exmoji.from_short_name(short_name),
     do: Exmoji.EmojiChar.render(emoji),
   else: match
  end

  defp auto_link(content, [], _repo), do: content
  defp auto_link(content, indexes, repo) do
    {content, rest, _offset} =
      Enum.reduce(List.flatten(indexes), {[], content, 0}, fn {idx, len}, {acc, rest, offset} ->
        {head, rest} = String.split_at(rest, idx - offset)
        {link, rest} =
          case String.split_at(rest, len) do
            {"#" <> number, rest} ->
              if issue = repo && IssueQuery.repo_issue(repo, String.to_integer(number)),
               do: {{"a", [{"href", Routes.issue_path(GitGud.Web.Endpoint, :show, repo.owner, repo, issue)}], ["##{number}"]}, rest},
             else: {"##{number}", rest}
            {"@" <> login, rest} ->
              if user = UserQuery.by_login(login),
                do: {{"a", [{"href", Routes.user_path(GitGud.Web.Endpoint, :show, user)}, {"class", "has-text-black"}], ["@#{login}"]}, rest},
              else: {"@#{login}", rest}
            {hash, rest} ->
              if repo do
                case GitAgent.revision(repo, hash) do
                  {:ok, commit, _ref} ->
                    {{"a", [{"href", Routes.codebase_path(GitGud.Web.Endpoint, :commit, repo.owner, repo, commit)}], [{"code", [{"class", "has-text-link"}], [hash]}]}, rest}
                  {:error, _reason} ->
                    nil
                end
              end || {hash, rest}
          end
        {acc ++ [head, link], rest, idx+len}
      end)
    List.flatten(content, [rest])
  end
end
