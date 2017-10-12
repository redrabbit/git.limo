defmodule GitGud.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    Supervisor.start_link([
      {GitGud.Repo, []},
      {GitGud.SSHServer, [8989, [system_dir: '/tmp/ssh_daemon', user_dir: '/tmp/ssh_daemon_keys']]},
    ], strategy: :one_for_one, name: GitGud.Supervisor)
  end
end
