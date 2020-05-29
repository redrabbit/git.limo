defmodule GitGud.Web.TrailingFormatPlug do
  @moduledoc """
  `Plug` providing support for routes with trailing format.
  """

  @behaviour Plug

  #
  # Callbacks
  #

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{path_info: []} = conn, _opts), do: conn
  def call(%Plug.Conn{path_info: path_info} = conn, _opts) do
    path =
      path_info
      |> List.last()
      |> String.split(".")
      |> Enum.reverse()

    case path do
      [_] -> conn
      [format|fragments] ->
        new_path =
          fragments
          |> Enum.reverse()
          |> Enum.join(".")
        path_fragments = List.replace_at(path_info, -1, new_path)
        params =
          conn
          |> Plug.Conn.fetch_query_params()
          |> Map.get(:params)
          |> update_params(new_path, format)
          |> Map.put("_format", format)
        %{conn|path_info: path_fragments, query_params: params, params: params}
    end
  end

  defp update_params(params, new_path, format) do
    if key = Enum.find_value(params, fn {key, val} -> val == "#{new_path}.#{format}" && key end),
      do: Map.put(params, key, new_path),
    else: params
  end
end
