use Mix.Config

config :gitgud,
  ssh_port: {:system, "SSH_PORT", 22},
  ssh_keys: {:system, "SSH_KEYS"},
  git_root: {:system, "GIT_ROOT"}

import_config "prod.secret.exs"
