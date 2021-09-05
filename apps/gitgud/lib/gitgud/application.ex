defmodule GitGud.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    telemetry_attach_git_agent()
    telemetry_attach_git_agent_instrument()
    telemetry_attach_git_wire_protocol()
    telemetry_attach_git_wire_protocol_instrument()
    telemetry_attach_graphql()
    telemetry_attach_ecto_instrument()

    children = [
      {Cluster.Supervisor, [Application.get_env(:libcluster, :topologies, []), [name: GitGud.ClusterSupervisor]]},
      {GitGud.DB, []},
      {GitGud.RepoSupervisor, []},
      {GitGud.SSHServer, []},
    ]
    Supervisor.start_link(children, strategy: :one_for_one, name: GitGud.Supervisor)
  end

  #
  # Helpers
  #

  defp telemetry_attach_git_agent do
    :telemetry.attach_many("git-agent",
      [
        [:gitrekt, :git_agent, :call],
        [:gitrekt, :git_agent, :call_stream],
        [:gitrekt, :git_agent, :execute],
        [:gitrekt, :git_agent, :stream],
        [:gitrekt, :git_agent, :transaction_start]
      ],
      &GitGud.Telemetry.GitLoggerHandler.handle_event/4, %{}
    )
  end

  defp telemetry_attach_git_agent_instrument do
    :telemetry.attach_many("git-agent-instrument",
      [
        [:gitrekt, :git_agent, :call],
        [:gitrekt, :git_agent, :call_stream],
        [:gitrekt, :git_agent, :execute],
        [:gitrekt, :git_agent, :stream],
        [:gitrekt, :git_agent, :transaction_start],
        [:gitrekt, :git_agent, :transaction_stop],
      ],
      &GitGud.Telemetry.GitInstrumentHandler.handle_event/4, %{}
    )
  end

  defp telemetry_attach_git_wire_protocol do
    :telemetry.attach_many("git-wire-protocol",
      [
        [:gitrekt, :wire_protocol, :start],
        [:gitrekt, :wire_protocol, :stop]
      ],
      &GitGud.Telemetry.GitLoggerHandler.handle_event/4, %{}
    )
  end

  defp telemetry_attach_git_wire_protocol_instrument do
    :telemetry.attach_many("git-wire-protocol-instrument",
      [
        [:gitrekt, :wire_protocol, :start],
        [:gitrekt, :wire_protocol, :stop]
      ],
      &GitGud.Telemetry.GitInstrumentHandler.handle_event/4, %{}
    )
  end

  defp telemetry_attach_graphql do
    :telemetry.attach("graphql", [:absinthe, :execute, :operation, :stop], &GitGud.Telemetry.GraphQLLoggerHandler.handle_event/4, %{})
  end

  defp telemetry_attach_ecto_instrument do
    :telemetry.attach("ecto-instrument", [:gitgud, :db, :query], &Appsignal.Ecto.handle_event/4, nil)
  end
end
