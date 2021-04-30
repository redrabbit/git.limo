defmodule GitGud.ReleaseTasks do
  @moduledoc """
  Conveniences for executing DB release tasks when run in production without Mix installed.
  """

  @app :gitgud

  @doc """
  Runs all pending migrations.
  """
  @spec migrate() :: :ok
  def migrate do
    load_app()
    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
    :ok
  end

  @doc """
  Reverts applied migrations down to and including version.
  """
  @spec rollback(module, term) :: :ok
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
