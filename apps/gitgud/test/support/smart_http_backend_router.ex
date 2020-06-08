defmodule GitGud.SmartHTTPBackendRouter do
  use Plug.Router

  alias GitGud.SmartHTTPBackend

  plug :match
  plug :fetch_query_params
  plug :dispatch

  get "/:user_login/:repo_name/info/refs", to: SmartHTTPBackend, init_opts: :discovery
  post "/:user_login/:repo_name/git-receive-pack", to: SmartHTTPBackend, init_opts: :receive_pack
  post "/:user_login/:repo_name/git-upload-pack", to: SmartHTTPBackend, init_opts: :upload_pack
end
