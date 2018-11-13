defmodule GitGud.Config do
  @moduledoc """
  Conveniences for fetching values from the config with some additional niceties.
  """

  @doc """
  Fetches a value from the config, or from the environment if {:system, "VAR"}
  is provided.

  An optional default value can be provided if desired.

  ## Example

      iex> {test_var, expected_value} = System.get_env |> Enum.take(1) |> List.first
      ...> Application.put_env(:myapp, :test_var, {:system, test_var})
      ...> ^expected_value = #{__MODULE__}.get(:myapp, :test_var)
      ...> :ok
      :ok

      iex> Application.put_env(:myapp, :test_var2, 1)
      ...> 1 = #{__MODULE__}.get(:myapp, :test_var2)
      1

      iex> :default = #{__MODULE__}.get(:myapp, :missing_var, :default)
      :default
  """
  @spec get(atom, atom, term | nil) :: term
  def get(app, key, default \\ nil) when is_atom(app) and is_atom(key) do
    case Application.get_env(app, key) do
      {:system, env_var} ->
        case System.get_env(env_var) do
          nil ->
            if default == :raise,
              do: raise("expected the #{env_var} environment variable to be set"),
            else: default
          val -> val
        end
      {:system, env_var, preconfigured_default} ->
        case System.get_env(env_var) do
          nil -> preconfigured_default
          val -> val
        end
      nil ->
        if default == :raise,
          do: raise("expected the #{key} configuration environment to be set"),
        else: default
      val ->
        val
    end
  end

  def get!(app, key) do
    get(app, key, :raise)
  end

  @doc """
  Same as get/3, but returns the result as an integer.
  If the value cannot be converted to an integer, the
  default is returned instead.
  """
  @spec get_integer(atom(), atom(), integer()) :: integer
  def get_integer(app, key, default \\ nil) do
    case get(app, key, default) do
      ^default -> default
      n when is_integer(n) -> n
      n ->
        case Integer.parse(n) do
          {i, _} -> i
          :error -> default
        end
    end
  end

  def get_integer!(app, key) do
    get_integer(app, key, :raise)
  end
end
