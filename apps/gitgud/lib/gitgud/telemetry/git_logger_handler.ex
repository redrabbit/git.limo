defmodule GitGud.Telemetry.GitLoggerHandler do
  @moduledoc false

  require Logger

  def handle_event([:gitrekt, :git_agent, :call], %{duration: duration}, %{op: op, args: args} = meta, _config) do
    agent_node = :erlang.node(meta.pid)
    if agent_node != Node.self() do
      args = Enum.join(map_git_agent_op_args(op, args) ++ map_git_agent_op_opts(op, meta), ", ")
      Logger.debug("[Git Agent] #{op}(#{args}) executed in #{duration_inspect(duration)} on #{agent_node}")
    end
  end

  def handle_event([:gitrekt, :git_agent, :call_stream], %{duration: duration}, %{op: op, args: args} = meta, _config) do
    agent_node = :erlang.node(meta.pid)
    if agent_node != Node.self() do
      args = Enum.join(map_git_agent_op_args(op, args) ++ map_git_agent_op_opts(op, meta), ", ")
      Logger.debug("[Git Agent] #{op}(#{args}) streamed items in #{duration_inspect(duration)} from #{agent_node}")
    end
  end

  def handle_event([:gitrekt, :git_agent, :execute], %{duration: duration}, %{op: op, args: args} = meta, _config) do
    args = Enum.join(map_git_agent_op_args(op, args) ++ map_git_agent_op_opts(op, meta), ", ")
    if Map.get(meta, :cache),
      do: Logger.debug("[Git Agent] #{op}(#{args}) executed in ⚡ #{duration_inspect(duration)}"),
    else: Logger.debug("[Git Agent] #{op}(#{args}) executed in #{duration_inspect(duration)}")
  end

  def handle_event([:gitrekt, :git_agent, :transaction_start], _measurements, %{op: op, args: args} = _meta, _config) do
    args = Enum.join(map_git_agent_op_args(op, args), ", ")
    Logger.debug("[Git Agent] #{op}(#{args}) started")
  end

  def handle_event([:gitrekt, :git_agent, :stream], %{duration: duration}, %{op: op, args: args} = meta, _config) do
    args = Enum.join(map_git_agent_op_args(op, args) ++ map_git_agent_op_opts(op, meta), ", ")
    Logger.debug("[Git Agent] #{op}(#{args}) streamed #{meta.stream_buffer_size} items in #{duration_inspect(duration)}")
  end

  def handle_event([:gitrekt, :wire_protocol, :start], _measurements, %{service: service, state: state} = _meta, _config) do
    Logger.debug("[Wire Protocol] #{service} start #{state}")
  end

  def handle_event([:gitrekt, :wire_protocol, :stop], %{duration: duration}, %{service: service, state: state} = _meta, _config) do
    Logger.debug("[Wire Protocol] #{service} executed #{state} in #{duration_inspect(duration)}")
  end

  #
  # Helpers
  #

  defp duration_inspect(duration) do
    cond do
      duration > 1_000_000 ->
        "#{Float.round(duration / 1_000_000, 2)} s"
      duration > 1_000 ->
        "#{Float.round(duration / 1_000, 2)} ms"
      true ->
        "#{duration} µs"
    end
  end

  defp inspect_oid(oid) do
    oid
    |> Base.encode16(case: :lower)
    |> String.slice(0, 7)
    |> then(&("<GitOID:#{&1}>"))
  end

  defp map_git_agent_op_args(:odb_read, [odb, oid]), do: [inspect(odb), inspect_oid(oid)]
  defp map_git_agent_op_args(:odb_write, [odb, data, type]), do: [inspect(odb), "<<... #{byte_size(data)} bytes>>", inspect(type)]
  defp map_git_agent_op_args(:odb_writepack_append, [writepack, data, _progress]), do: [inspect(writepack), "<<... #{byte_size(data)} bytes>>"]
  defp map_git_agent_op_args(:odb_writepack_commit, [writepack, progress]), do: [inspect(writepack), "#{progress.received_objects} objects - #{progress.received_bytes} bytes"]
  defp map_git_agent_op_args(:odb_object_exists?, [odb, oid]), do: [inspect(odb), inspect_oid(oid)]
  defp map_git_agent_op_args(:references, [:undefined, opts]), do: Enum.map(opts, &inspect/1)
  defp map_git_agent_op_args(:references_with, [:undefined, opts]), do: Enum.map(opts, &inspect/1)
  defp map_git_agent_op_args(:reference_create, [name, :oid, oid, force]), do: [inspect(name), inspect(:oid), inspect_oid(oid), "force: #{force}"]
  defp map_git_agent_op_args(:object, [oid]), do: [inspect_oid(oid)]
  defp map_git_agent_op_args(:graph_ahead_behind, [oid, oid]), do: [inspect_oid(oid), inspect_oid(oid)]
  defp map_git_agent_op_args(:commit_create, [update_ref, author, committer, message, tree_oid, parents_oids]), do: [inspect(update_ref), inspect(author), inspect(committer), inspect(message), inspect_oid(tree_oid), inspect(Enum.map(parents_oids, &inspect_oid/1))]
  defp map_git_agent_op_args(:tree_entry, [revision, {:oid, oid}]), do: [inspect(revision), inspect({:oid, inspect_oid(oid)})]
  defp map_git_agent_op_args(:index_add, [index, oid, path, file_size, mode, opts]), do: [inspect(index), inspect_oid(oid), inspect(path), inspect(file_size), inspect(mode), inspect(opts)]
  defp map_git_agent_op_args(:pack_create, [oids]), do: [inspect(Enum.map(oids, &inspect_oid/1))]
  defp map_git_agent_op_args(:transaction, [{:blob_commit, oid, path}, _callback]), do: [":blob_commit", inspect_oid(oid), inspect(path)]
  defp map_git_agent_op_args(:transaction, [{:history_count, oid}, _callback]), do: [":history_count", inspect_oid(oid)]
  defp map_git_agent_op_args(:transaction, [{:tree_entries_with_commit, oid, path}, _callback]), do: [":tree_entries_with_commit", inspect_oid(oid), inspect(path)]
  defp map_git_agent_op_args(:transaction, [nil, callback]), do: [inspect(callback)]

  defp map_git_agent_op_args(_op, args), do: Enum.map(args, &inspect/1)

  defp map_git_agent_op_opts(_op, %{stream_chunk_size: chunk_size}), do: ["stream_chunk_size: #{chunk_size}"]
  defp map_git_agent_op_opts(_op, _meta), do: []
end
