import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :gitgud_web, GitGud.Web.Endpoint,
  http: [port: 4001],
  server: false

# Use Bamboo test adapter
config :gitgud_web, GitGud.Mailer, adapter: Bamboo.TestAdapter

# Reduce number of rounds for password hashing
config :argon2_elixir, t_cost: 2, m_cost: 12
