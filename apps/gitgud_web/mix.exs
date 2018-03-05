defmodule GitGud.Web.Mixfile do
  use Mix.Project

  def project do
    [app: :gitgud_web,
     version: "0.1.0",
     build_path: "../../_build",
     config_path: "../../config/config.exs",
     deps_path: "../../deps",
     lockfile: "../../mix.lock",
     elixir: "~> 1.4",
     elixirc_paths: elixirc_paths(Mix.env),
     compilers: [:phoenix, :gettext] ++ Mix.compilers,
     start_permanent: Mix.env == :prod,
     aliases: aliases(),
     deps: deps()]
  end

  def application do
    [mod: {GitGud.Web.Application, []},
     extra_applications: [:logger, :runtime_tools]]
  end

  #
  # Helpers
  #

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  defp deps do
    [{:cowboy, "~> 1.1"},
     {:phoenix, "~> 1.3"},
     {:phoenix_html, "~> 2.10"},
     {:phoenix_pubsub, "~> 1.0"},
     {:phoenix_live_reload, "~> 1.1", only: :dev},
     {:phoenix_ecto, "~> 3.3"},
     {:absinthe_plug, "~> 1.4"},
     {:gettext, "~> 0.15"},
     {:gitgud, in_umbrella: true}]
  end

  defp aliases do
    ["test": ["ecto.create --quiet", "ecto.migrate", "test"]]
  end
end
