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
config :gitgud,
  ssh_port: 9899,
  ssh_keys: Path.absname("priv/ssh-keys", Path.dirname(__DIR__)),
  git_root: Path.absname("test/data/git", Path.dirname(__DIR__))
