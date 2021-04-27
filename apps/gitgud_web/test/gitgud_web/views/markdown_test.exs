defmodule GitGud.Web.MarkdownTest do
  use ExUnit.Case, async: true

  alias GitGud.User

  alias GitGud.Web.Router.Helpers, as: Routes

  import GitGud.Web.Markdown

  test "formats typography" do
    assert {:ok, html} = Floki.parse_fragment(markdown("**This is bold text**"))
    assert Floki.text(Floki.find(html, "p strong")) == "This is bold text"
    assert {:ok, html} = Floki.parse_fragment(markdown("__This is bold text__"))
    assert Floki.text(Floki.find(html, "p strong")) == "This is bold text"
    assert {:ok, html} = Floki.parse_fragment(markdown("*This is italic text*"))
    assert Floki.text(Floki.find(html, "p em")) == "This is italic text"
    assert {:ok, html} = Floki.parse_fragment(markdown("_This is italic text_"))
    assert Floki.text(Floki.find(html, "p em")) == "This is italic text"
  end

  test "formats emoji" do
    assert {:ok, html} = Floki.parse_fragment(markdown("This is a :rainbow:"))
    assert String.trim(Floki.text(Floki.find(html, "p"))) == "This is a 🌈"
  end

  test "formats mention" do
    user = struct(User, login: "redrabbit", name: "Mario Flach")
    assert {:ok, html} = Floki.parse_fragment(markdown("Say hello to @#{user.login}", users: [user]))
    html_mention = Floki.find(html, "p a")
    assert Floki.attribute(html_mention, "href") == [Routes.user_path(GitGud.Web.Endpoint, :show, user)]
    assert Floki.text(html_mention) == "@" <> user.login
  end
end
