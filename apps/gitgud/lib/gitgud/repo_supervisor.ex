defmodule GitGud.RepoSupervisor do
  @moduledoc """
  Supervisor for dealing with repository processes.
  """
  use Supervisor

  alias GitRekt.GitAgent

  alias GitGud.Repo
  alias GitGud.RepoStorage

  @doc """
  Starts the supervisor as part of a supervision tree.
  """
  @spec start_link(Supervisor.options) ::  {:ok, pid} | {:error, {:already_started, pid} | {:shutdown, term} | term}
  def start_link(opts \\ []) do
    opts = Keyword.put(opts, :name, __MODULE__)
    Supervisor.start_link(__MODULE__, [], opts)
  end

  @doc """
  Starts a `GitRekt.GitAgent` process for the given `repo`.
  """
  @spec start_agent(Repo.t) :: DynamicSupervisor.on_start_child
  def start_agent(repo) do
    via_registry = {:via, Registry, {GitGud.GitAgentRegistry, "#{repo.owner.login}/#{repo.name}", repo}}
    DynamicSupervisor.start_child(GitGud.GitAgentSupervisor, %{
      id: GitAgent,
      start: {GitAgent, :start_link, [RepoStorage.init_param(repo), [name: via_registry]]}
    })
  end

  @doc """
  Finds a repository in the registry.
  """
  @spec lookup(binary, binary) :: Repo.t | nil
  def lookup(user_login, repo_name), do: lookup(Path.join(user_login, repo_name))

  @doc """
  Finds a repository in the registry.
  """
  @spec lookup(Path.t) :: Repo.t | nil
  def lookup(path) do
    case Registry.lookup(GitGud.GitAgentRegistry, path) do
      [{pid, repo}] -> struct(repo, __agent__: pid)
      [] -> nil
    end
  end

  #
  # Callbacks
  #

  @impl true
  def init([]) do
    children = [
      {Registry, keys: :unique, name: GitGud.GitAgentRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: GitGud.GitAgentSupervisor}
    ]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
