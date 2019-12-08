defmodule GitGud.RepoPoolMonitor do
  @moduledoc """
  Conveniences for managing repository process ownership and live-time.
  """
  use GenServer

  @idle_timeout 30_000

  @doc """
  Starts the monitor as part of a supervision tree.
  """
  @spec start_link(keyword) :: GenServer.on_start
  def start_link(opts \\ []) do
    opts = Keyword.put(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, [], opts)
  end

  @doc """
  Adds a reference to the `agent` shared ownership.
  """
  @spec monitor(pid) :: pid
  def monitor(agent) do
    GenServer.cast(__MODULE__, {:monitor, agent, self()})
    agent
  end

  #
  # Callbacks
  #

  @impl true
  def init([]) do
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:monitor, agent, pid}, agents) do
    new_ref = Process.monitor(pid)
    refs =
      case Map.get(agents, agent) do
        nil ->
          Process.monitor(agent)
          [new_ref]
        refs when is_list(refs) ->
          [new_ref|refs]
        {_time, _ref} = timer ->
          {:ok, :cancel} = :timer.cancel(timer)
          [new_ref]
      end
    agents = Map.put(agents, agent, refs)
    {:noreply, agents}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, pid, _reason}, agents) do
    case Map.pop(agents, pid) do
      {nil, agents} ->
        agents = Enum.reduce(agents, %{}, fn {agent, refs}, acc ->
          cond do
            [ref] == refs ->
              {:ok, timer} = :timer.exit_after(@idle_timeout, agent, :kill)
              Map.put(acc, agent, timer)
            is_list(refs) && ref in refs ->
              Map.put(acc, agent, List.delete(refs, ref))
            true ->
              Map.put(acc, agent, refs)
          end
        end)
        {:noreply, agents}
      {refs, agents} when is_list(refs) ->
        Enum.each(refs, &Process.demonitor/1)
        {:noreply, agents}
      {{_time, _ref} = timer, agents} ->
        {:ok, :cancel} = :timer.cancel(timer)
        {:noreply, agents}
    end
  end
end
