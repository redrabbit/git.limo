use Mix.Config

config :gitgud,
  ecto_repos: [GitGud.Repo],
  git_dir: "/Users/redrabbit/Devel/Elixir/gitgud/apps/gitgud/git-data",
  ssh_system_dir: "/Users/redrabbit/Devel/Elixir/gitgud/apps/gitgud/ssh-keys"

import_config "#{Mix.env}.exs"
