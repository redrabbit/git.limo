defmodule GitGud.Web.GraphQLPlug do
  @moduledoc false

  use Plug.Router

  plug :match
  plug :dispatch

  forward "/", to: Absinthe.Plug.GraphiQL, init_opts: [json_codec: Jason, socket: GitGud.Web.UserSocket, schema: GitGud.GraphQL.Schema]
end
