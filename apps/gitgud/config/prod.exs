use Mix.Config

# Configure your SSH server
config :gitgud,
  ssh_port: 22,
  ssh_keys: System.get_env("SSH_KEYS"),
  git_root: System.get_env("GIT_ROOT")

# Do not print debug messages in production
config :logger, level: :info
