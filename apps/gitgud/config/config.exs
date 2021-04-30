import Config

# General application configuration
config :gitgud,
  namespace: GitGud,
  ecto_repos: [GitGud.DB]

# Configure Telemetry prefix for Ecto repository GitGud.DB
config :gitgud, GitGud.DB, telemetry_prefix: [:gitgud, :db]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
