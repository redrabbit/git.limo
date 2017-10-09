defmodule GitGud.Application do
  @moduledoc """
  The GitGud Application Service.

  The gitgud system business domain lives in this application.

  Exposes API to clients such as the `GitGudWeb` application
  for use in channels, controllers, and elsewhere.
  """
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    Supervisor.start_link([
      supervisor(GitGud.Repo, []),
    ], strategy: :one_for_one, name: GitGud.Supervisor)
  end
end
