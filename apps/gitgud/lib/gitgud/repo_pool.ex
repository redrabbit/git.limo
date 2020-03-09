defmodule GitGud.RepoPool do
  @moduledoc """
  Conveniences for working with a pool of repository processes.
  """
  use DynamicSupervisor

  alias GitRekt.GitAgent

  alias GitGud.RepoStorage
  alias GitGud.RepoRegistry

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
  @spec start_agent(Repo.t) :: {:ok, pid} | {:error, term}
  def start_agent(repo) do
    via_registry = {:via, Registry, {RepoRegistry, "#{repo.owner.login}/#{repo.name}"}}
    child_spec = %{
      id: GitAgent,
      start: {GitAgent, :start_link, [RepoStorage.workdir(repo), [name: via_registry, idle_timeout: 30_000]]},
      restart: :temporary
    }
    case DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, pid} ->
        {:ok, pid}
      {:error, {:already_started, pid}} ->
        {:ok, pid}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Finds a repository in the registry.
  """
  @spec lookup(binary, binary) :: pid | nil
  def lookup(user_login, repo_name), do: lookup(Path.join(user_login, repo_name))

  @doc """
  Finds a repository in the registry.
  """
  @spec lookup(Path.t) :: pid | nil
  def lookup(path) do
    case Registry.lookup(GitGud.RepoRegistry, path) do
      [{pid, _meta}] -> pid
      [] -> nil
    end
  end

  #
  # Callbacks
  #

  @impl true
  def init([]),  do: DynamicSupervisor.init(strategy: :one_for_one)
end
