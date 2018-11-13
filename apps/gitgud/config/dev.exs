use Mix.Config

# Configure your database
config :gitgud, GitGud.DB,
  username: "postgres",
  password: "postgres",
  database: "gitgud_dev",
  hostname: "localhost",
  pool_size: 10

config :gitgud, GitGud.SSHServer,
  port: 8989,
  key_path: Path.absname("priv/ssh-keys", Path.dirname(__DIR__))

config :gitgud, GitGud.Repo,
  root_path: Path.absname("priv/git-data", Path.dirname(__DIR__))

