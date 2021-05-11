defmodule GitGud.RepoPool do
  @moduledoc """
  Dynamic pool of Git repository agent processes.
  """
  use DynamicSupervisor

  alias GitRekt.Git
  alias GitRekt.GitAgent

  alias GitGud.Repo
  alias GitGud.RepoStorage
  alias GitGud.RepoRegistry

  @behaviour NimblePool

  @doc """
  Starts the pool as part of a supervision tree.
  """
  def start_link(opts \\ []) do
    opts = Keyword.put(opts, :name, __MODULE__)
    DynamicSupervisor.start_link(__MODULE__, [], opts)
  end

  @doc """
  Starts a `GitRekt.GitAgent` process for the given `repo`.
  """
  @spec start_agent(Repo.t, keyword) :: {:ok, pid} | {:error, term}
  def start_agent(repo, opts \\ []) do
    via_registry = {:via, Registry, {RepoRegistry, "#{repo.owner_login}/#{repo.name}"}}
    agent_opts = Keyword.merge([name: via_registry, idle_timeout: 900_000], opts)
    child_spec = %{
      id: GitAgent,
      start: {GitAgent, :start_link, [RepoStorage.workdir(repo), agent_opts]},
      restart: :temporary
    }
    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  @doc """
  Checks out a transaction for the given `repo`.
  """
  @spec checkout(Repo.t, term | nil, (GitRekt.GitAgent.agent -> {:ok, term} | {:error, term})) :: {:ok, term} | {:error, term}
  def checkout(repo, name \\ nil, cb, opts \\ []) do
    {timeout, opts} = Keyword.pop(opts, :timeout, 5_000)
    via_registry = {:via, Registry, {RepoRegistry, "pool/#{repo.owner_login}/#{repo.name}"}}
    child_spec = {NimblePool, worker: {__MODULE__, RepoStorage.workdir(repo)}, name: via_registry}
    case DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, pool} ->
        NimblePool.checkout!(pool, :transaction, fn _from, agent -> {GitAgent.transaction(agent, name, cb, opts), {:transaction, name}} end, timeout)
      {:error, {:already_started, pool}} ->
        NimblePool.checkout!(pool, :transaction, fn _from, agent -> {GitAgent.transaction(agent, name, cb, opts), {:transaction, name}} end, timeout)
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Retrieves an agent from the registry.
  """
  @spec lookup(Repo.t | Path.t) :: pid | nil
  def lookup(%Repo{} = repo), do: lookup(Path.join(repo.owner_login, repo.name))
  def lookup(path) do
    case Registry.lookup(GitGud.RepoRegistry, path) do
      [{agent, nil}] -> agent
      [] -> nil
    end
  end

  #
  # Callbacks
  #

  @impl DynamicSupervisor
  def init([]),  do: DynamicSupervisor.init(strategy: :one_for_one)

  @impl NimblePool
  def init_pool(path) do
    {:ok, {path, :ets.new(__MODULE__, [:set, :public])}}
  end


  @impl NimblePool
  def init_worker({path, _cache} = pool_state) do
    case Git.repository_open(path) do
      {:ok, handle} ->
        {:ok, handle, pool_state}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl NimblePool
  def handle_checkout(:transaction, _from, handle, {_path, cache} = pool_state) do
    {:ok, {handle, cache}, handle, pool_state}
  end

  @impl NimblePool
  def handle_checkin(_client_state, _from, handle, pool_state) do
    {:ok, handle, pool_state}
  end

end
