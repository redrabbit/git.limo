use Mix.Config

config :gitgud, GitGud.SSHServer,
  port: {:system, "SSH_PORT", 22},
  key_path: {:system, "SSH_KEYS"}

config :gitgud, GitGud.Repo,
  root_path: {:system, "GIT_ROOT"}

import_config "prod.secret.exs"
