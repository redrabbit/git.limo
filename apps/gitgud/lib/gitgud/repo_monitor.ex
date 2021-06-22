defmodule GitGud.RepoMonitor do
  @moduledoc """
  Conveniences for monitoring repositories life-times.
  """
  use GenServer

  @doc """
  Starts the monitor as part of a supervision tree.
  """
  @spec start_link(keyword) :: GenServer.on_start
  def start_link(opts) do
    opts = Keyword.put(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, [], opts)
  end

  @doc """
  Monitors the given `agent` in the given `pool`.
  """
  @spec monitor(pid, pid) :: :ok
  def monitor(pool, agent), do: GenServer.cast(__MODULE__, {:monitor, pool, agent})

  #
  # Callbacks
  #

  @impl true
  def init([]) do
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:monitor, pool, agent}, state) do
    ref = Process.monitor(agent)
    {:noreply, Map.update(state, pool, [ref], &[ref|&1])}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _agent, _reason}, state) do
    {
      :noreply,
      state
      |> Enum.flat_map(&remove_ref(&1, ref))
      |> Enum.into(%{})
    }
  end

  #
  # Helpers
  #

  defp remove_ref({pool, refs}, ref) do
    case refs do
      [^ref] ->
        DynamicSupervisor.stop(pool)
        []
      refs ->
        [{pool, List.delete(refs, ref)}]
    end
  end
end
