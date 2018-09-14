use Mix.Config

config :gitgud,
  ecto_repos: [GitGud.DB],
  git_root: "priv/git-data",
  ssh_keys: "priv/ssh-keys"

config :absinthe, schema: GitGud.GraphQL.Schema

import_config "#{Mix.env}.exs"
