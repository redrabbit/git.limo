defmodule GitGud.Web.GraphQLPlug do
  @moduledoc false

  use Plug.Router

  plug :match
  plug :authenticate_context
  plug :dispatch

  forward "/",
    to: Absinthe.Plug.GraphiQL,
    init_opts: [
      json_codec: Jason,
      socket: GitGud.Web.UserSocket,
      schema: GitGud.GraphQL.Schema
    ]

  #
  # Helpers
  #

  defp authenticate_context(conn, _opts) do
    if user = GitGud.Web.AuthenticationPlug.current_user(conn),
      do: Absinthe.Plug.assign_context(conn, :current_user, user),
    else: conn
  end
end
