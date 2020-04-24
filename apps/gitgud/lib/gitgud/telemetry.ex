defmodule GitGud.Telemetry do
  @moduledoc false

  require Logger

  def handle_event([:gitrekt, :git_agent, :call], %{latency: latency}, %{op: op, args: args}, _config) do
    args = Enum.join(map_git_agent_op_args(op, args), ", ")
    latency = if latency > 1_000, do: "#{latency / 1_000} ms", else: "#{latency} µs"
    Logger.debug("[Git Agent] #{op}(#{args}) executed in #{latency}")
  end

  def handle_event([:gitrekt, :wire_protocol, command], %{latency: latency}, %{service: service}, _config) do
    latency = if latency > 1_000, do: "#{latency / 1_000} ms", else: "#{latency} µs"
    Logger.debug("[Wire Protocol] #{command} executed #{service.state} in #{latency}")
  end

  #
  # Helpers
  #

  defp map_git_agent_op_args(:odb_read, [odb, oid]), do: [inspect(odb), oid_inspect(oid)]
  defp map_git_agent_op_args(:odb_write, [odb, data, type]), do: [inspect(odb), "<<... #{byte_size(data)} bytes>>", inspect(type)]
  defp map_git_agent_op_args(:odb_object_exists?, [odb, oid]), do: [inspect(odb), oid_inspect(oid)]
  defp map_git_agent_op_args(:reference_create, [name, :oid, oid, force]), do: [inspect(name), inspect(:oid), oid_inspect(oid), inspect(force)]
  defp map_git_agent_op_args(:object, [oid]), do: [oid_inspect(oid)]
  defp map_git_agent_op_args(:commit_create, [update_ref, author, committer, message, tree_oid, parents_oids]), do: [inspect(update_ref), inspect(author), inspect(committer), inspect(message), oid_inspect(tree_oid), inspect(Enum.map(parents_oids, &oid_inspect/1))]
  defp map_git_agent_op_args(:tree_entry, [revision, {:oid, oid}]), do: [inspect(revision), inspect({:oid, oid_inspect(oid)})]
  defp map_git_agent_op_args(:index_add, [index, oid, path, file_size, mode, opts]), do: [inspect(index), oid_inspect(oid), inspect(path), inspect(file_size), inspect(mode), inspect(opts)]
  defp map_git_agent_op_args(:pack_create, [oids]), do: [inspect(Enum.map(oids, &oid_inspect/1))]
  defp map_git_agent_op_args(_op, args), do: Enum.map(args, &inspect/1)

  defp oid_inspect(oid) do
    oid
    |> Base.encode16(case: :lower)
    |> inspect()
  end
end
