import Config

# General application configuration
config :gitgud_web,
  namespace: GitGud.Web,
  ecto_repos: [GitGud.DB]

# Configures the endpoint
config :gitgud_web, GitGud.Web.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "Orcr/BYzysTwrdJaOA7vu7miC2V5M2ivU6yMY7hW1cUnegxFej5GLalozFC+f6uA",
  live_view: [signing_salt: "+GxMLCpWTHUwhpTzG0SBr+DULSa+gzYA"],
  render_errors: [view: GitGud.Web.ErrorView, accepts: ~w(html)],
  pubsub_server: GitGud.Web.PubSub

# Configure generators
config :gitgud_web, :generators,
  context_app: :gitgud

# Absinthe GraphQL schema
config :absinthe, schema: GitGud.GraphQL.Schema

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Use Jason for JSON parsing in Bamboo
config :bamboo, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
