import Config

# Do not print debug messages in production
config :logger, level: :info

config :appsignal, :config, active: true
