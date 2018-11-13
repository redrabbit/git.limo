use Mix.Config

# Configure your database
config :gitgud, GitGud.DB,
  username: "postgres",
  password: "postgres",
  database: "gitgud_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :gitgud, GitGud.SSHServer,
  port: 8989,
  key_path: Path.absname("priv/ssh-keys", Path.dirname(__DIR__))

config :gitgud, GitGud.Repo,
  root_path: Path.absname("test/data/git", Path.dirname(__DIR__))

