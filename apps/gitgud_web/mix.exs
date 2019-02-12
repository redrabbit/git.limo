defmodule GitGud.Web.Mixfile do
  use Mix.Project

  def project do
    [app: :gitgud_web,
     version: "0.2.0",
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

  defp elixirc_paths(:test), do: ["lib", "test/support", "../gitgud/test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  defp deps do
    [{:ecto, "~> 3.0", override: true},
     {:plug, "~> 1.7"},
     {:plug_cowboy, "~> 2.0"},
     {:phoenix, "~> 1.4"},
     {:phoenix_html, "~> 2.12"},
     {:phoenix_pubsub, "~> 1.1"},
     {:phoenix_live_reload, "~> 1.2", only: :dev},
     {:phoenix_ecto, "~> 4.0"},
     {:absinthe, "~> 1.5.0-alpha.2", override: true},
     {:absinthe_relay, "~> 1.5.0-alpha.0", override: true},
     {:absinthe_phoenix, github: "absinthe-graphql/absinthe_phoenix"},
     {:oauth2, "~> 0.9"},
     {:bamboo, github: "thoughtbot/bamboo"},
     {:gettext, "~> 0.15"},
     {:timex, "~> 3.4"},
     {:earmark, "~> 1.3"},
     {:gitgud, in_umbrella: true}]
  end

  defp aliases do
    [test: ["ecto.create --quiet", "ecto.migrate", "test"]]
  end
end
