defmodule GitGud.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    :telemetry.attach("appsignal-ecto", [:gitgud, :db, :query], &Appsignal.Ecto.handle_event/4, nil)

    Supervisor.start_link([
      {GitGud.DB, []},
      {GitGud.SSHServer, []},
    ], strategy: :one_for_one, name: GitGud.Supervisor)
  end
end
