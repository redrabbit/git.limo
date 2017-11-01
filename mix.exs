defmodule GitGud.Umbrella.Mixfile do
  use Mix.Project

  def project do
    [apps_path: "apps",
     name: "Git Gud",
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  #
  # Helpers
  #

  defp deps do
    [{:ex_doc, "~> 0.18", only: :dev, runtime: false}]
  end
end
