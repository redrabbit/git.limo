use Mix.Config

# Do not print debug messages in production
config :logger, level: :info

# Activate AppSignal error and metric report
config :appsignal, :config, active: true
