use Mix.Config

# Configure your database
config :gitgud, GitGud.DB,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "gitgud_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :gitgud, :git_root_dir, "test/git-root"
