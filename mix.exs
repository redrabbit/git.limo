defmodule GitGud.Umbrella.Mixfile do
  use Mix.Project

  def project do
    [apps_path: "apps",
     start_permanent: Mix.env == :prod,
     deps: []]
  end
end
