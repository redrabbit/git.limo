use Mix.Config

# General application configuration
config :gitgud_web,
  namespace: GitGud.Web,
  ecto_repos: [GitGud.DB]

# Configures the endpoint
config :gitgud_web, GitGud.Web.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "Orcr/BYzysTwrdJaOA7vu7miC2V5M2ivU6yMY7hW1cUnegxFej5GLalozFC+f6uA",
  render_errors: [view: GitGud.Web.ErrorView, accepts: ~w(json)],
  pubsub: [name: GitGud.Web.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :gitgud_web, :generators,
  context_app: :gitgud

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
