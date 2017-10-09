use Mix.Config

config :gitgud, ecto_repos: [GitGud.Repo]

import_config "#{Mix.env}.exs"
