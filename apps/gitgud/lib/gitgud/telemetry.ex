defmodule GitGud.Telemetry do
  @moduledoc false

  require Logger

  def handle_event([:gitrekt, :git_agent, :call], %{latency: latency}, %{op: op, args: args}, _config) do
    args = Enum.join(Enum.map(args, &"#{inspect &1}"), ", ")
    latency = if latency > 1_000, do: "#{latency / 1_000} ms", else: "#{latency} µs"
    Logger.debug("GitAgent.#{op}(#{args}) executed in #{latency}")
  end
end
