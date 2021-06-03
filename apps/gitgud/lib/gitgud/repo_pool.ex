defmodule GitGud.RepoPool do
  @moduledoc """
  Dynamic pool of Git repository agent processes.
  """
  use DynamicSupervisor

  alias GitRekt.GitAgent

  alias GitGud.Repo
  alias GitGud.RepoStorage
  alias GitGud.RepoRegistry

  @doc """
  Starts the pool as part of a supervision tree.
  """
  @spec start_link(keyword) :: Supervisor.on_start
  def start_link(opts \\ []) do
    opts = Keyword.put(opts, :name, __MODULE__)
    DynamicSupervisor.start_link(__MODULE__, [], opts)
  end

  @spec start_pool(Repo.t, keyword) :: Supervisor.on_start
  def start_pool(repo, opts \\ []) do
    via_registry = {:via, Registry, {RepoRegistry, "#{repo.owner_login}/#{repo.name}"}}
    opts = Keyword.put(opts, :name, via_registry)
    DynamicSupervisor.start_link(__MODULE__, RepoStorage.workdir(repo), opts)
  end

  @doc """
  Starts a `GitRekt.GitAgent` process for the given `repo`.
  """
  @spec start_agent(Repo.t) :: {:ok, pid} | {:error, term}
  def start_agent(repo) do
    pool_child_spec = %{id: :pool, start: {__MODULE__, :start_pool, [repo]}, restart: :temporary}
    agent_child_spec = %{id: :agent, start: {GitAgent, :start_link, []}, restart: :temporary}
    case DynamicSupervisor.start_child(__MODULE__, pool_child_spec) do
      {:ok, pool} ->
        DynamicSupervisor.start_child(pool, agent_child_spec)
      {:error, {:already_started, pool}} ->
        DynamicSupervisor.start_child(pool, agent_child_spec)
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
      [{pool, nil}] ->
        case Enum.random(DynamicSupervisor.which_children(pool)) do
          {:undefined, agent, :worker, [GitAgent]} when is_pid(agent) ->
            agent
        end
      [] ->
        nil
    end
  end

  #
  # Callbacks
  #

  @impl true
  def init([]),  do: DynamicSupervisor.init(strategy: :one_for_one)
  def init(workdir) do
    cache = GitAgent.init_cache(workdir, [])
    DynamicSupervisor.init(
      strategy: :one_for_one,
      max_children: 5,
      extra_arguments: [
        workdir,
        [
          cache: cache,
          idle_timeout: 120_000
        ]
      ]
    )
  end
end
