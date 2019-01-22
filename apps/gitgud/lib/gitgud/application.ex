defmodule GitGud.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    Supervisor.start_link([
      {GitGud.DB, []},
      {GitGud.SSHServer, []},
    ], strategy: :one_for_one, name: GitGud.Supervisor)
  end
end
