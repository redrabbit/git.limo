defmodule GitRekt.Mixfile do
  use Mix.Project

  def project do
    [app: :gitrekt,
     version: "0.1.0",
     build_path: "../../_build",
     config_path: "../../config/config.exs",
     deps_path: "../../deps",
     lockfile: "../../mix.lock",
     elixir: "~> 1.5",
     compilers: [:elixir_make] ++ Mix.compilers,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [{:elixir_make, "~> 0.4"}]
  end
end
