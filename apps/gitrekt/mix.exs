defmodule GitRekt.Mixfile do
  use Mix.Project

  def project do
    [
      app: :gitrekt,
      version: "0.3.9",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.5",
      compilers: [:elixir_make] ++ Mix.compilers,
      make_args: ["--quiet"],
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  #
  # Helpers
  #

  defp deps do
    [
      {:elixir_make, "~> 0.6"},
      {:stream_split, "~> 0.1"},
      {:telemetry, "~> 1.1"}
    ]
  end
end
