use Mix.Config

config :gitgud,
  namespace: GitGud,
  ecto_repos: [GitGud.DB]

config :absinthe, schema: GitGud.GraphQL.Schema

import_config "#{Mix.env}.exs"
