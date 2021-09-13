defmodule GitGud.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    :telemetry.attach_many("git-agent",
      [
        [:gitrekt, :git_agent, :call],
        [:gitrekt, :git_agent, :call_stream],
      # [:gitrekt, :git_agent, :execute],
      # [:gitrekt, :git_agent, :stream],
      # [:gitrekt, :git_agent, :transaction_start],
      # [:gitrekt, :git_agent, :transaction_stop]
      ],
      &GitGud.Telemetry.handle_event/4, %{}
    )

    :telemetry.attach_many("git-wire-protocol",
      [
        [:gitrekt, :wire_protocol, :start],
        [:gitrekt, :wire_protocol, :stop]
      ],
      &GitGud.Telemetry.handle_event/4, %{}
    )

    :telemetry.attach("graphql", [:absinthe, :execute, :operation, :stop], &GitGud.Telemetry.handle_event/4, %{})

    children = [
      {Cluster.Supervisor, [Application.get_env(:libcluster, :topologies, []), [name: GitGud.ClusterSupervisor]]},
      {GitGud.DB, []},
      {GitGud.RepoSupervisor, []},
      {GitGud.SSHServer, []},
    ]
    Supervisor.start_link(children, strategy: :one_for_one, name: GitGud.Supervisor)
  end
end
