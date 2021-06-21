import Config

# Configure your database
config :gitgud, GitGud.DB,
  username: "postgres",
  password: "postgres",
  database: "gitgud_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

# Configure your database for GitHub Actions
if System.get_env("GITHUB_ACTIONS") do
  config :gitgud, GitGud.DB,
    username: "postgres",
    password: "postgres"
end

# Configure your SSH server
config :gitgud, GitGud.SSHServer,
  port: 9899,
  host_key_dir: Path.absname("priv/ssh-keys", Path.dirname(__DIR__))

# Configure your Git storage location
config :gitgud, GitGud.RepoStorage,
  git_root: Path.absname("test/data/git", Path.dirname(__DIR__))

# Configure your repository pool
config :gitgud, GitGud.RepoPool,
  max_children_per_pool: 3
