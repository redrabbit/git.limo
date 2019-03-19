defmodule GitGud.SmartHTTPBackendRouter do
  use Plug.Router

  plug :match
  plug :fetch_query_params
  plug :dispatch

  forward "/:user_login/:repo_name", to: GitGud.SmartHTTPBackend
end
