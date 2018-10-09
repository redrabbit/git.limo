defmodule GitGud.DataFactory do
  @moduledoc """
  This module provides functions to generate all kind of test data.
  """

  import Faker.Name, only: [name: 0]
  import Faker.Internet, only: [email: 0, user_name: 0]

  @doc """
  Returns a map representing `GitGud.User` registration params.
  """
  def user do
    %{name: name(), username: String.replace(user_name(), ~r/[^a-zA-Z0-9_-]/, "-", global: true), email: email(), password: "qwertz"}
  end

  @doc false
  defmacro __using__(_opts) do
    quote do
      def factory(name, params \\ []) do
        Map.merge(apply(unquote(__MODULE__), name, []), Map.new(params))
      end
    end
  end
end
