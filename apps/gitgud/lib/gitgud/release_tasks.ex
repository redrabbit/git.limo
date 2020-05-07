defmodule GitGud.ReleaseTasks do
  @moduledoc false

  @app :gitgud

  def migrate do
    load_app()
    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
    :ok
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
    :ok
  end

  #
  # Helpers
  #

  defp load_app, do: Application.load(@app)

  defp repos, do: Application.fetch_env!(@app, :ecto_repos)
end
