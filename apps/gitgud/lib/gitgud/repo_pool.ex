defmodule GitGud.RepoPool do
  @moduledoc """
  Dynamic pool of Git repository agent processes.
  """
  use DynamicSupervisor

  alias GitRekt.GitAgent

  alias GitGud.Repo
  alias GitGud.RepoMonitor
  alias GitGud.RepoStorage
  alias GitGud.RepoRegistry

  @agent_idle_timeout Application.compile_env(:gitgud, [__MODULE__, :idle_timeout], 1_800_000)
  @max_children_per_pool Application.compile_env(:gitgud, [__MODULE__, :max_children_per_pool], 5)

  @doc """
  Starts the pool as part of a supervision tree.
  """
  @spec start_link(keyword) :: Supervisor.on_start
  def start_link(opts \\ []) do
    opts = Keyword.put(opts, :name, __MODULE__)
    DynamicSupervisor.start_link(__MODULE__, [], opts)
  end

  @doc """
  Starts a dedicated supervisor for the given `repo`.
  """
  @spec start_pool(Repo.t, keyword) :: Supervisor.on_start
  def start_pool(repo, opts \\ []) do
    via_registry = {:via, Registry, {RepoRegistry, "#{repo.owner_login}/#{repo.name}"}}
    opts = Keyword.put(opts, :name, via_registry)
    DynamicSupervisor.start_link(__MODULE__, {Path.join(repo.owner_login, repo.name), RepoStorage.workdir(repo)}, opts)
  end

  @doc """
  Returns a `GitRekt.GitAgent` process for the given `repo`.
  """
  @spec checkout(Repo.t) :: {:ok, pid} | {:error, term}
  def checkout(%Repo{} = repo) do
    case spawn_pool_agent(repo) do
      {:ok, agent} ->
        {:ok, agent}
      {:error, :max_children} ->
        lookup_agent(repo)
      {:error, reason} ->
        {:error, reason}
    end
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
  def init([]) do
    :ets.new(__MODULE__, [:public, :named_table])
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def init({path, workdir}) do
    :ets.insert(__MODULE__, {path, -1})
    DynamicSupervisor.init(
      strategy: :one_for_one,
      max_children: @max_children_per_pool,
      extra_arguments: [
        workdir,
        [
          cache: :ets.new(Module.concat(__MODULE__, Cache), [:set, :public]),
          idle_timeout: @agent_idle_timeout
        ]
      ]
    )
  end

  #
  # Helpers
  #

  defp spawn_pool_agent(repo) do
    child_spec = %{id: :pool, start: {__MODULE__, :start_pool, [repo]}, restart: :temporary}
    case DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, pool} ->
        spawn_agent(pool)
      {:error, {:already_started, pool}} ->
        spawn_agent(pool)
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp spawn_agent(pool) do
    child_spec = %{id: :agent, start: {GitAgent, :start_link, []}, restart: :temporary}
    case DynamicSupervisor.start_child(pool, child_spec) do
      {:ok, agent} ->
        GenServer.call(RepoMonitor, {:monitor, pool, agent})
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp lookup_agent(%Repo{} = repo), do: lookup_agent(Path.join(repo.owner_login, repo.name))
  defp lookup_agent(path) do
    case Registry.lookup(GitGud.RepoRegistry, path) do
      [{pool, nil}] ->
        index = :ets.update_counter(__MODULE__, path, {2, 1, @max_children_per_pool - 1, 0})
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
