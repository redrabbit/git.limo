defmodule GitGud.Telemetry.GraphQLLoggerHandler do
  @moduledoc false

  require Logger

  def handle_event([:absinthe, :execute, :operation, :stop], %{duration: duration}, meta, _config) do
    [%{name: name, type: type, args: args}|_] = Enum.map(meta.blueprint.operations, &map_absinthe_op/1)
    args = Enum.join(map_absinthe_op_args(args), ", ")
    Logger.debug("[GraphQL] #{type} #{name}(#{args}) executed in #{duration_inspect(duration / 1_000)}")
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

  defp map_absinthe_op(%Absinthe.Blueprint.Document.Operation{name: name, type: type, variable_definitions: var_defs, variable_uses: var_uses}) when is_binary(name) do
    %{name: name, type: type, args: Enum.map(var_uses, fn %{name: name} -> {name, Enum.find_value(var_defs, &(&1.name == name && map_absinthe_input_value(&1.provided_value)))} end)}
  end

  defp map_absinthe_op(%Absinthe.Blueprint.Document.Operation{type: type, selections: [selection|_]}) do
    %{name: selection.name, type: type, args: Enum.map(selection.argument_data, fn {key, val} -> {Absinthe.Utils.camelize(to_string(key), lower: true), val} end)}
  end

  defp map_absinthe_op_args(args), do: Enum.map(args, fn {name, val} -> "#{name}: #{inspect(val)}" end)

  defp map_absinthe_input_value(%Absinthe.Blueprint.Input.RawValue{content: input_value}), do: map_absinthe_input_value(input_value)
  defp map_absinthe_input_value(%Absinthe.Blueprint.Input.List{items: []}), do: []
  defp map_absinthe_input_value(%Absinthe.Blueprint.Input.List{items: items}), do: Enum.map(items, &map_absinthe_input_value/1)
  defp map_absinthe_input_value(%{value: value}), do: value
end
