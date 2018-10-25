defmodule GitGud.Web.Gravatar do
  @moduledoc """
  Conveniences for generating Gravatar URLs.
  """

  @domain "gravatar.com/avatar/"

  def gravatar_url(email, opts \\ []) do
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
