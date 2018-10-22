use Mix.Config

# Configure your database
config :gitgud, GitGud.DB,
  username: "postgres",
  password: "postgres",
  database: "gitgud_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :gitgud,
  ssh_keys: Path.absname("priv/ssh-keys", Path.dirname(__DIR__)),
  git_root: Path.absname("test/data/git", Path.dirname(__DIR__))

