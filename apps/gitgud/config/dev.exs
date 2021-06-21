import Config

# Configure your database
config :gitgud, GitGud.DB,
  username: "postgres",
  password: "postgres",
  database: "gitgud_dev",
  hostname: "localhost",
  pool_size: 10

# Configure your SSH server
config :gitgud, GitGud.SSHServer,
  port: 8989,
  host_key_dir: Path.absname("priv/ssh-keys", Path.dirname(__DIR__))

# Configure your Git storage location
config :gitgud, GitGud.RepoStorage,
  git_root: Path.absname("priv/git-data", Path.dirname(__DIR__))

# Configure your repository pool
config :gitgud, GitGud.RepoPool,
  max_children_per_pool: 5
