defmodule GitGud.Mixfile do
  use Mix.Project

  def project do
    [app: :gitgud,
     name: "Git Rekt",
     version: "0.0.1",
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

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  defp deps do
    [{:postgrex, ">= 0.0.0"},
     {:ecto, "~> 2.2"},
     {:comeonin, "~> 4.0"},
     {:argon2_elixir, "~> 1.2"},
     {:geef, github: "carlosmn/geef"},
     {:ex_doc, "~> 0.18", only: :dev, runtime: false}]
  end

  defp aliases do
    ["ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
     "ecto.reset": ["ecto.drop", "ecto.setup"],
     "test": ["ecto.create --quiet", "ecto.migrate", "test"]]
  end
end
