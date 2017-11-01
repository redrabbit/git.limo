use Mix.Config

# Configure your database
config :gitgud, GitGud.QuerySet,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "gitgud_dev",
  hostname: "localhost",
  pool_size: 10
