defmodule GitGud.Web.Gravatar do
  @moduledoc """
  Conveniences for generating Gravatar URLs.
  """

  alias GitGud.Email
  alias GitGud.User

  import Phoenix.HTML.Tag

  @domain "gravatar.com/avatar/"

  @spec gravatar(User.t|Email.t|binary, keyword) :: binary
  def gravatar(email, opts \\ []) do
    opts = Keyword.put_new(opts, :size, 20)
    {size, opts} = Keyword.get_and_update(opts, :size, &{&1, &1*2})
    img_tag(gravatar_url(email, opts), class: "avatar", width: size)
  end

  @spec gravatar_url(User.t|Email.t|binary, keyword) :: binary
  def gravatar_url(email, opts \\ [])
  def gravatar_url(%User{primary_email: email}, opts), do: gravatar_url(email, opts)
  def gravatar_url(%Email{email: email}, opts), do: gravatar_url(email, opts)
  def gravatar_url(email, opts) when is_binary(email) do
    {secure, opts} = Keyword.pop(opts, :secure, true)
    %URI{}
    |> host(secure)
    |> hash_email(email)
    |> parse_options(opts)
    |> to_string()
  end

  #
  # Helpers
  #

  defp parse_options(uri, []), do: uri
  defp parse_options(uri, opts), do: %URI{uri|query: URI.encode_query(opts)}

  defp host(uri, true),  do: %URI{uri|scheme: "https", host: "secure.#{@domain}"}
  defp host(uri, false), do: %URI{uri|scheme: "http",  host: @domain}

  defp hash_email(uri, email) do
    hash = Base.encode16(:crypto.hash(:md5, String.downcase(email)), case: :lower)
      %URI{uri | path: hash}
  end
end
