defmodule GitGud.Web.Gravatar do
  @moduledoc """
  Conveniences for rendering Gravatars.
  """

  alias GitGud.User

  import Phoenix.HTML.Tag

  @doc """
  Renders a Gravatar widget for the given `email`.
  """
  @spec gravatar(User.t, keyword) :: binary
  def gravatar(%User{avatar_url: nil}, _opts), do: []
  def gravatar(%User{avatar_url: url}, opts) do
    {size, opts} = Keyword.get_and_update(opts, :size, &{&1, &1*2})
    url = URI.parse(url)
    url = struct(url, query: URI.encode_query(opts))
    img_class = if size < 28, do: "avatar is-small", else: "avatar"
    img_tag(to_string(url), class: img_class, width: size)
  end
end
