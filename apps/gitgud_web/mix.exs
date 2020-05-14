defmodule GitGud.Web.Mixfile do
  use Mix.Project

  def project do
    [app: :gitgud_web,
     version: "0.3.0",
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
    [{:ecto, "~> 3.4"},
     {:plug, "~> 1.10"},
     {:plug_cowboy, "~> 2.2"},
     {:phoenix, "~> 1.5"},
     {:phoenix_html, "~> 2.14"},
     {:phoenix_pubsub, "~> 2.0"},
     {:phoenix_live_reload, "~> 1.2", only: :dev},
     {:phoenix_ecto, "~> 4.1"},
     {:absinthe, "~> 1.5"},
     {:absinthe_relay, "~> 1.5"},
     {:absinthe_phoenix, "~> 2.0"},
     {:oauth2, "~> 2.0"},
     {:bamboo, "~> 1.5"},
     {:gettext, "~> 0.17"},
     {:timex, "~> 3.6"},
     {:earmark, "~> 1.4"},
     {:exmoji, "~> 0.2"},
     {:floki, "~> 0.26", only: :test},
     {:gitgud, in_umbrella: true}]
  end

  defp aliases do
    [test: ["ecto.create --quiet", "ecto.migrate", "test"]]
  end
end
