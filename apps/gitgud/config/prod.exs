use Mix.Config

config :gitgud,
  ssh_port: 22,
  ssh_keys: System.get_env("SSH_KEYS"),
  git_root: System.get_env("GIT_ROOT")

import_config "prod.secret.exs"
