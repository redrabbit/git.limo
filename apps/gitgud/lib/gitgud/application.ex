defmodule GitGud.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    :telemetry.attach("git-agent", [:gitrekt, :git_agent, :call], &GitGud.Telemetry.handle_event/4, %{})
    :telemetry.attach("git-upload-pack", [:gitrekt, :wire_protocol, :upload_pack], &GitGud.Telemetry.handle_event/4, %{})
    :telemetry.attach("git-receive-pack", [:gitrekt, :wire_protocol, :receive_pack], &GitGud.Telemetry.handle_event/4, %{})

    Supervisor.start_link([
      {GitGud.DB, []},
      {GitGud.SSHServer, []},
    ], strategy: :one_for_one, name: GitGud.Supervisor)
  end
end
