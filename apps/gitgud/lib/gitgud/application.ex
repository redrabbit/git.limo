defmodule GitGud.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    :telemetry.attach_many("git-agent", [[:gitrekt, :git_agent, :call], [:gitrekt, :git_agent, :stream]], &GitGud.Telemetry.handle_event/4, %{})
    :telemetry.attach_many("git-agent-cache", [[:gitrekt, :git_agent, :init_cache], [:gitrekt, :git_agent, :fetch_cache], [:gitrekt, :git_agent, :put_cache]], &GitGud.Telemetry.handle_event/4, %{})
    :telemetry.attach("git-upload-pack", [:gitrekt, :wire_protocol, :upload_pack], &GitGud.Telemetry.handle_event/4, %{})
    :telemetry.attach("git-receive-pack", [:gitrekt, :wire_protocol, :receive_pack], &GitGud.Telemetry.handle_event/4, %{})
    :telemetry.attach("graphql", [:absinthe, :execute, :operation, :stop], &GitGud.Telemetry.handle_event/4, %{})

    children = [
      {GitGud.DB, []},
      {GitGud.RepoSupervisor, []},
      {GitGud.SSHServer, []},
    ]
    Supervisor.start_link(children, strategy: :one_for_one, name: GitGud.Supervisor)
  end
end
