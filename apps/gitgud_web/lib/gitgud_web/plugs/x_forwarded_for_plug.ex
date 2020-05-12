defmodule GitGud.Web.XForwardedForPlug do
  @moduledoc """
  `Plug` providing support for `X-Forwared-For` header.
  """

  @behaviour Plug

  #
  # Callbacks
  #

  @impl true
  def init(opts), do: %{header: opts[:header] || "x-forwarded-for"}

  @impl true
  def call(conn, %{header: header}) do
    conn
    |> Plug.Conn.get_req_header(header)
    |> process_header(conn)
  end

  #
  # Helpers
  #

  defp process_header([], conn), do: conn
  defp process_header([val|_], conn), do: parse_address(val, conn)

  defp parse_address(<<>>, conn), do: conn
  defp parse_address(<<" ", rest :: binary>>, conn), do: parse_address(rest, conn)

  for length <- 7..39 do
    defp parse_address(<<ip :: binary-size(unquote(length)), " ", _ :: binary>>, conn), do: replace_address(ip, conn)
    defp parse_address(<<ip :: binary-size(unquote(length)), ",", _ :: binary>>, conn), do: replace_address(ip, conn)
    defp parse_address(<<ip :: binary-size(unquote(length))>>, conn), do: replace_address(ip, conn)
  end

  defp parse_address(_val, conn), do: conn

  defp replace_address(ip, conn) do
    case :inet_parse.address(:erlang.binary_to_list(ip)) do
      {:ok, address} ->
        %{conn | remote_ip: address}
      {:error, _reason} ->
        conn
    end
  end
end
