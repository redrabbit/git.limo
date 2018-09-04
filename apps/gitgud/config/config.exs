use Mix.Config

config :gitgud,
  ecto_repos: [GitGud.DB],
  git_dir: "/Users/redrabbit/Devel/Elixir/gitgud/apps/gitgud/git-data",
  ssh_key_dir: "/Users/redrabbit/Devel/Elixir/gitgud/apps/gitgud/ssh-keys"

config :absinthe, schema: GitGud.GraphQL.Schema

import_config "#{Mix.env}.exs"
