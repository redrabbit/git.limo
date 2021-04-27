defmodule GitGud.Web.GravatarTest do
  use ExUnit.Case, async: true

  alias GitGud.User

  import Phoenix.HTML.Safe

  import GitGud.Web.Gravatar

  test "renders avatar image" do
    avatar_url = "https://gravatar.com/avatar/1234567890"
    avatar = gravatar(%User{avatar_url: avatar_url})
    assert {:ok, html} = Floki.parse_fragment(to_iodata(avatar))
    assert html_img = Floki.find(html, "img")
    assert Floki.attribute(html_img, "src") == [avatar_url <> "?size=56"]
    assert Floki.attribute(html_img, "width") == ["28"]
  end

  test "renders avatar image with custom size" do
    avatar_url = "https://gravatar.com/avatar/1234567890"
    avatar = gravatar(%User{avatar_url: avatar_url}, size: 64)
    assert {:ok, html} = Floki.parse_fragment(to_iodata(avatar))
    assert html_img = Floki.find(html, "img")
    assert Floki.attribute(html_img, "src") == [avatar_url <> "?size=128"]
    assert Floki.attribute(html_img, "width") == ["64"]
  end

  test "renders nothing if user has no avatar" do
    assert gravatar(%User{}) == []
  end
end
