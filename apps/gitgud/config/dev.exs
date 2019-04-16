use Mix.Config

# Configure your database
config :gitgud, GitGud.DB,
  username: "postgres",
  password: "postgres",
  database: "gitgud_dev",
  hostname: "localhost",
  pool_size: 10

# Configure your SSH server
config :gitgud,
  ssh_port: 8989,
  ssh_keys: Path.absname("priv/ssh-keys", Path.dirname(__DIR__)),
  git_storage: :postgres,
  git_root: Path.absname("priv/git-data", Path.dirname(__DIR__))
