defmodule GitGud.Mixfile do
  use Mix.Project

  def project do
    [
      app: :gitgud,
      version: "0.3.9",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.4",
      elixirc_paths: elixirc_paths(Mix.env),
      start_permanent: Mix.env == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {GitGud.Application, []},
      extra_applications: [:logger, :runtime_tools, :ssh]
    ]
  end

  #
  # Helpers
  #

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:absinthe, "~> 1.7", optional: true},
      {:argon2_elixir, "~> 3.0"},
      {:ecto, "~> 3.9"},
      {:ecto_sql, "~> 3.9"},
      {:faker, "~> 0.17", only: :test},
      {:gitrekt, in_umbrella: true},
      {:jason, "~> 1.4"},
      {:phoenix, "~> 1.6", optional: true},
      {:phoenix_pubsub, "~> 2.1", optional: true},
      {:plug, "~> 1.13", optional: true},
      {:plug_cowboy, "~> 2.5", only: :test},
      {:postgrex, "~> 0.16"},
      {:telemetry, "~> 1.1"},
      {:libcluster, "~> 3.3"}
    ]
  end

  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/db/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end
end
