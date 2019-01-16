use Mix.Config

config :gitgud,
  namespace: GitGud,
  ecto_repos: [GitGud.DB]

config :gitgud, GitGud.DB,
  telemetry_prefix: [:gitgud, :db]

import_config "#{Mix.env}.exs"
