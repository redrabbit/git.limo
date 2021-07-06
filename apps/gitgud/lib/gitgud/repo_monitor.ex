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

  #
  # Callbacks
  #

  @impl true
  def init([]) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:monitor, pool, agent}, _from, state) do
    ref = Process.monitor(agent)
    {:reply, {:ok, agent}, Map.update(state, pool, [ref], &[ref|&1])}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _agent, _reason}, state) do
    {state, empty_pools} = Enum.flat_map_reduce(state, [], &demonitor(&1, ref, &2))
    Enum.each(empty_pools, &DynamicSupervisor.stop/1)
    {:noreply, Map.new(state)}
  end

  #
  # Helpers
  #

  defp demonitor({pool, refs}, ref, acc) do
    case refs do
      [^ref] ->
        {[], [pool|acc]}
      refs ->
        {[{pool, List.delete(refs, ref)}], acc}
    end
  end
end
