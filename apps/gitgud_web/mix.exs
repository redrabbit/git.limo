defmodule GitGud.Web.Mixfile do
  use Mix.Project

  def project do
    [
      app: :gitgud_web,
      version: "0.3.8",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.4",
      elixirc_paths: elixirc_paths(Mix.env),
      compilers: [:phoenix] ++ Mix.compilers,
      start_permanent: Mix.env == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {GitGud.Web.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  #
  # Helpers
  #

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:absinthe, "~> 1.7"},
      {:absinthe_relay, "~> 1.5"},
      {:absinthe_phoenix, "~> 2.0"},
      {:appsignal, "~> 2.1"},
      {:appsignal_phoenix, "~> 2.0"},
      {:appsignal_plug, "~> 2.0"},
      {:bamboo, "~> 2.2"},
      {:bamboo_phoenix, "~> 1.0"},
      {:earmark, "~> 1.4"},
      {:floki, "~> 0.33", only: :test},
      {:gettext, "~> 0.20"},
      {:gitgud, in_umbrella: true},
      {:oauth2, "~> 2.0"},
      {:phoenix, "~> 1.6"},
      {:phoenix_ecto, "~> 4.4"},
      {:phoenix_html, "~> 3.2"},
      {:phoenix_live_reload, "~> 1.3", only: :dev},
      {:phoenix_live_view, "~> 0.18"},
      {:phoenix_pubsub, "~> 2.1"},
      {:plug, "~> 1.13"},
      {:plug_cowboy, "~> 2.5"},
      {:timex, "~> 3.7"},
    ]
  end

  defp aliases do
    [
      "assets.deploy": ["cmd --cd assets node build.js --deploy", "phx.digest"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end
end
