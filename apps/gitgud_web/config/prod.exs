use Mix.Config

# For production, we often load configuration from external
# sources, such as your system environment. For this reason,
# you won't find the :http configuration below, but set inside
# GitGud.Web.Endpoint.init/2 when load_from_system_env is
# true. Any dynamic configuration should be done there.
config :gitgud_web, GitGud.Web.Endpoint,
  load_from_system_env: true,
  http: [port: {:system, "PORT"}],
  url: [host: "locahost", port: {:system, "PORT"}],
  cache_static_manifest: "priv/static/cache_manifest.json"

# Finally import the config/prod.secret.exs
# which should be versioned separately.
import_config "prod.secret.exs"
