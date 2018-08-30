defmodule GitGud.Mixfile do
  use Mix.Project

  def project do
    [app: :gitgud,
     version: "0.1.0",
     build_path: "../../_build",
     config_path: "../../config/config.exs",
     deps_path: "../../deps",
     lockfile: "../../mix.lock",
     elixir: "~> 1.4",
     elixirc_paths: elixirc_paths(Mix.env),
     start_permanent: Mix.env == :prod,
     aliases: aliases(),
     deps: deps()]
  end

  def application do
    [mod: {GitGud.Application, []},
     extra_applications: [:logger, :runtime_tools, :ssh]]
  end

  #
  # Helpers
  #

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  defp deps do
    [{:postgrex, ">= 0.0.0"},
     {:ecto, "~> 2.2"},
     {:comeonin, "~> 4.1"},
     {:argon2_elixir, "~> 1.2"},
     {:absinthe, "~> 1.4"},
     {:dataloader, "~> 1.0"},
     {:gitrekt, in_umbrella: true}]
  end

  defp aliases do
    ["ecto.setup": ["ecto.create", "ecto.migrate", "run priv/db/seeds.exs"],
     "ecto.reset": ["ecto.drop", "ecto.setup"],
     test: ["ecto.create --quiet", "ecto.migrate", "test"]]
  end
end
