defmodule GitGud.Web.Endpoint do
  @moduledoc """
  HTTP and WebSocket endpoints.
  """

  use Phoenix.Endpoint, otp_app: :gitgud_web
  use Absinthe.Phoenix.Endpoint

  socket "/socket", GitGud.Web.UserSocket, websocket: true

  plug Plug.Static,
    at: "/", from: :gitgud_web, gzip: false,
    only: ~w(css fonts images js favicon.ico robots.txt)

  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId
  plug Plug.Logger

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason

  plug Plug.MethodOverride
  plug Plug.Head

  plug Plug.Session,
    store: :cookie,
    key: "_gitgud_web_key",
    signing_salt: "zMguVWdH"

  plug GitGud.Web.Router

  def init(_key, config) do
    if config[:load_from_system_env] do
      port = System.get_env("PORT") || raise "expected the PORT environment variable to be set"
      {:ok, Keyword.put(config, :http, [:inet6, port: port])}
    else
      {:ok, config}
    end
  end
end
