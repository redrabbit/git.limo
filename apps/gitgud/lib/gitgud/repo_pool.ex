defmodule GitGud.RepoPool do
  @moduledoc """
  Dynamic pool of Git repository agent processes.
  """
  use GenServer

  alias GitRekt.GitAgent

  alias GitGud.Repo
  alias GitGud.RepoSupervisor
  alias GitGud.RepoStorage

  @agent_idle_timeout Application.compile_env(:gitgud, [__MODULE__, :idle_timeout], 1_800_000)
  @max_children_per_pool Application.compile_env(:gitgud, [__MODULE__, :max_children_per_pool], 5)

  @doc """
  Starts the pool as part of a supervision tree.
  """
  @spec start_link(Supervisor.option | Supervisor.init_option) :: Supervisor.on_start
  def start_link(volume, opts \\ []) do
    opts = Keyword.put(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, {:volume, volume}, opts)
  end

  @doc """
  Starts a dedicated supervisor for the given `repo`.
  """
  @spec start_pool(Repo.t | Path.t, keyword) :: Supervisor.on_start
  def start_pool(repo, opts \\ [])
  def start_pool(%Repo{owner_login: user_login, name: repo_name} = _repo, opts), do: start_pool(Path.join(user_login, repo_name), opts)
  def start_pool(path, opts) do
    opts = Keyword.put(opts, :name, {:via, Registry, {Module.concat(__MODULE__, Registry), path}})
    DynamicSupervisor.start_link(__MODULE__, {:pool, path}, opts)
  end

  @doc """
  Returns a `GitRekt.GitAgent` process for the given `repo`.
  """
  @spec checkout(Repo.t) :: {:ok, pid} | {:error, term}
  def checkout(%Repo{} = repo) do
    GenServer.call(RepoSupervisor.volume_name(__MODULE__, repo.volume), {:checkout, Path.join(repo.owner_login, repo.name)})
  end

  @doc """
  Similar to `checkout/1`, but also monitors the agent process.
  """
  @spec checkout_monitor(Repo.t) :: {:ok, pid} | {:error, term}
  def checkout_monitor(repo) do
    case checkout(repo) do
      {:ok, agent} ->
        Process.monitor(agent)
        {:ok, agent}
      {:error, reason} ->
        {:error, reason}
    end
  end

  #
  # Callbacks
  #

  @impl true
  def init({:volume, vol}) do
    with :ok <- RepoSupervisor.register_volume(__MODULE__, vol),
        {:ok, sup} <- DynamicSupervisor.start_link(strategy: :one_for_one, name: Module.concat(__MODULE__, DynamicSupervisor)),
        {:ok, reg} <- Registry.start_link(keys: :unique, name: Module.concat(__MODULE__, Registry)) do
      {:ok, %{vol: vol, sup: sup, reg: reg, tab: :ets.new(__MODULE__, [])}}
    end
  end

  def init({:pool, path}) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      max_children: @max_children_per_pool,
      extra_arguments: [
        Path.join(Keyword.fetch!(Application.get_env(:gitgud, RepoStorage), :git_root), path),
        [
          cache: :ets.new(Module.concat(__MODULE__, Cache), [:set, :public]),
          idle_timeout: @agent_idle_timeout
        ]
      ]
    )
  end

  @impl true
  def handle_call({:checkout, path}, _from, %{sup: sup, tab: tab} = state) do
    case spawn_pool_agent(sup, path, tab) do
      {:ok, agent} ->
        {:reply, {:ok, agent}, state}
      {:error, :max_children} ->
        {:reply, lookup_agent(path, tab), state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  #
  # Helpers
  #

  defp spawn_pool_agent(sup, path, tab) do
    child_spec = %{id: :repo_pool, start: {__MODULE__, :start_pool, [path]}, restart: :temporary}
    case DynamicSupervisor.start_child(sup, child_spec) do
      {:ok, pool} ->
        :ets.insert(tab, {path, -1})
        spawn_agent(pool)
      {:error, {:already_started, pool}} ->
        spawn_agent(pool)
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp spawn_agent(pool) do
    child_spec = %{id: :agent, start: {GitAgent, :start_link, []}, restart: :temporary}
    DynamicSupervisor.start_child(pool, child_spec)
  end

  defp lookup_agent(path, tab) do
    case Registry.lookup(Module.concat(__MODULE__, Registry), path) do
      [{pool, nil}] ->
        index = :ets.update_counter(tab, path, {2, 1, @max_children_per_pool - 1, 0})
        children = DynamicSupervisor.which_children(pool)
        case Enum.at(children, rem(index, length(children))) do
          {:undefined, agent, :worker, [_mod]} when is_pid(agent) ->
            {:ok, agent}
          nil ->
            {:error, "pool out of bounds for #{path}"}
        end
      [] ->
        {:error, "no pool available for #{path}"}
    end
  end
end
