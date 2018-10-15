defmodule GitGud.Web.DataFactory do
  @moduledoc """
  This module provides functions to generate all kind of test data.
  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      def factory(name, params \\ []) do
        try do
          apply(unquote(__MODULE__), name, List.wrap(params))
        rescue
          UndefinedFunctionError ->
            apply(GitGud.DataFactory, name, List.wrap(params))
        end
      end
    end
  end
end

