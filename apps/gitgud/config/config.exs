use Mix.Config

config :gitgud,
  ecto_repos: [GitGud.Repo],
  ssh_system_dir: "/tmp/ssh_daemon"

import_config "#{Mix.env}.exs"
