use Mix.Config

# Print only warnings and errors during test
config :logger, level: :warn

# Reduce number of rounds for password hashing
config :argon2_elixir, t_cost: 2, m_cost: 12
