defmodule GitGud.RepoSupervisor do
  @moduledoc """
  Supervisor for dealing with repository processes.
  """
  use Supervisor

  alias GitGud.RepoPool
  alias GitGud.RepoStorage

  @doc """
  Starts the supervisor as part of a supervision tree.
  """
  @spec start_link(Supervisor.option | Supervisor.init_option) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    opts = Keyword.put(opts, :name, __MODULE__)
    Supervisor.start_link(__MODULE__, [], opts)
  end

  @doc """
  Returns a process name for a given module and volume.
  """
  @spec volume_name(module, binary | nil) :: term
  def volume_name(mod, nil), do: mod
  def volume_name(mod, volume), do: {:global, {mod, volume}}

  @doc """
  Registers the current process and volume with an unique name.
  """
  @spec register_volume(module, binary | nil) :: :ok | {:error, {:already_started, pid}}
  def register_volume(_mod, nil), do: :ok
  def register_volume(mod, volume) do
    global_name = {mod, volume}
    case :global.register_name(global_name, self()) do
      :yes ->
        :ok
      :no ->
        {:error, {:already_started, :global.whereis_name(global_name)}}
    end
  end

  #
  # Callbacks
  #

  @impl true
  def init([]) do
    case RepoStorage.ensure_volume_tagged() do
      {:ok, volume} ->
        children = [
          {RepoStorage, volume},
          {RepoPool, volume},
        ]
        Supervisor.init(children, strategy: :one_for_one)
      {:error, reason} ->
        {:stop, reason}
    end
  end
end
