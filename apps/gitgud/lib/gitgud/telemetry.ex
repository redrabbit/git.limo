defmodule GitGud.Telemetry do
  @moduledoc false

  require Logger

  def handle_event([:gitrekt, :git_agent, :execute], %{duration: duration}, %{op: op, args: args} = meta, _config) do
    args = Enum.join(map_git_agent_op_args(op, args), ", ")
    if Map.get(meta, :cache),
      do: Logger.debug("[Git Agent] #{op}(#{args}) executed in #{duration_inspect(duration)} ⚡"),
    else: Logger.debug("[Git Agent] #{op}(#{args}) executed in #{duration_inspect(duration)}")
  end

  def handle_event([:gitrekt, :git_agent, :stream], %{duration: duration}, %{op: op, args: args, chunk_size: chunk_size}, _config) do
    args = Enum.join(map_git_agent_op_args(op, args), ", ")
    Logger.debug("[Git Agent] #{op}(#{args}) streamed #{chunk_size} items in #{duration_inspect(duration)}")
  end

  def handle_event([:gitrekt, :git_agent, :init_cache], %{duration: duration}, %{args: [path]}, _config) do
    Logger.debug("[Git Agent] init cache for #{path} in #{duration_inspect(duration)}")
  end

  def handle_event([:gitrekt, :git_agent, :fetch_cache], %{duration: duration}, %{op: op, args: args}, _config) do
    args = Enum.join(map_git_agent_op_args(op, args), ", ")
    Logger.debug("[Git Agent] #{op}(#{args}) fetched from cache in #{duration_inspect(duration)}")
  end

  def handle_event([:gitrekt, :git_agent, :put_cache], %{duration: duration}, %{op: op, args: args}, _config) do
    args = Enum.join(map_git_agent_op_args(op, args), ", ")
    Logger.debug("[Git Agent] #{op}(#{args}) cached in #{duration_inspect(duration)}")
  end

  def handle_event([:gitrekt, :wire_protocol, command], %{duration: duration}, %{service: service}, _config) do
    Logger.debug("[Wire Protocol] #{command} executed #{service.state} in #{duration_inspect(duration)}")
  end

  def handle_event([:absinthe, :execute, :operation, :stop], %{duration: duration}, meta, _config) do
    [%{name: name, type: type, args: args}|_] = Enum.map(meta.blueprint.operations, &map_absinthe_op/1)
    args = Enum.join(map_absinthe_op_args(args), ", ")
    Logger.debug("[GraphQL] #{type} #{name}(#{args}) executed in #{duration_inspect(duration)}")
  end

  #
  # Helpers
  #

  defp duration_inspect(duration) do
    if duration > 1_000_000,
      do: "#{Float.round(duration / 1_000_000, 2)} ms",
    else: "#{Float.round(duration / 1_000, 2)} µs"
  end

  defp oid_inspect(oid) do
    oid
    |> Base.encode16(case: :lower)
    |> inspect()
  end

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

  defp map_absinthe_op(%Absinthe.Blueprint.Document.Operation{name: name, type: type, variable_definitions: var_defs, variable_uses: var_uses}) when is_binary(name) do
    %{name: name, type: type, args: Enum.map(var_uses, fn %{name: name} -> {name, Enum.find_value(var_defs, &(&1.name == name && map_absinthe_input_value(&1.provided_value)))} end)}
  end

  defp map_absinthe_op(%Absinthe.Blueprint.Document.Operation{type: type, selections: [selection|_]}) do
    %{name: selection.name, type: type, args: Enum.map(selection.argument_data, fn {key, val} -> {Absinthe.Utils.camelize(to_string(key), lower: true), val} end)}
  end

  defp map_absinthe_op_args(args) do
    Enum.map(args, fn {name, val} -> "#{name}: #{inspect(val)}" end)
  end

  defp map_absinthe_input_value(%Absinthe.Blueprint.Input.RawValue{content: input_value}), do: map_absinthe_input_value(input_value)
  defp map_absinthe_input_value(%Absinthe.Blueprint.Input.List{items: []}), do: []
  defp map_absinthe_input_value(%Absinthe.Blueprint.Input.List{items: items}), do: Enum.map(items, &map_absinthe_input_value/1)
  defp map_absinthe_input_value(%{value: value}), do: value

# defp map_absinthe_field(i) when is_integer(i), do: [to_string(i)]
# defp map_absinthe_field(%Absinthe.Blueprint.Document.Field{name: name}), do: [name]
# defp map_absinthe_field(%Absinthe.Blueprint.Document.Operation{}), do: []
# def map_absinthe_field(%Absinthe.Blueprint.Document.Operation{} = op) do
#   %{name: name, args: args} = map_absinthe_op(op)
#   args = Enum.join(map_absinthe_op_args(args), ", ")
#   ["#{name}(#{args})"]
# end

end
