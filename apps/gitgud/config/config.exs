use Mix.Config

config :gitgud, ecto_repos: [GitGud.DB]

config :absinthe, schema: GitGud.GraphQL.Schema

import_config "#{Mix.env}.exs"
