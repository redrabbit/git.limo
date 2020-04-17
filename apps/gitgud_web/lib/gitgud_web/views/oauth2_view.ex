defmodule GitGud.Web.OAuth2View do
  @moduledoc false
  use GitGud.Web, {:view, path: "oauth2"}

  import Phoenix.HTML.Tag

  @spec signin_button(Plug.Conn.t, binary, keyword) :: binary
  def signin_button(conn, provider, attrs \\ []) do
    attrs
    |> Keyword.put(:to, Routes.oauth2_path(conn, :authorize, provider))
    |> Keyword.put_new(:class, "button is-small #{provider}")
    |> link(do: [content_tag(:span, [class: "icon"], do: provider_icon(provider)), content_tag(:span, provider_name(provider))])
  end

  @spec provider_icon(binary) :: binary
  def provider_name("github"), do: "GitHub"
  def provider_name("gitlab"), do: "GitLab"
  def provider_name("bitbucket"), do: "BitBucket"

  @spec provider_icon(binary) :: binary
  def provider_icon(provider), do: content_tag(:i, "", [class: "fab fa-lg fa-#{provider}"])

  @spec title(atom, map) :: binary
  def title(_action, _assigns), do: "Settings · OAuth2.0"
end
