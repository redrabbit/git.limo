defmodule GitGud.RepoStorage do
  @moduledoc """
  Conveniences for storing Git objects and meta objects.
  """
  use GenServer

  alias GitRekt.Git

  alias GitGud.Repo
  alias GitGud.RepoSupervisor

  @doc """
  Starts the storage server as part of a supervision tree.
  """
  @spec start_link(binary, keyword) :: GenServer.on_start
  def start_link(volume, opts \\ []) do
    opts = Keyword.put(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, {:volume, volume}, opts)
  end

  @doc """
  Initializes a new Git repository for the given `repo`.
  """
  @spec init(Repo.t, boolean) :: {:ok, Git.repo} | {:error, term}
  def init(%Repo{} = repo, bare?) do
    GenServer.call(RepoSupervisor.volume_name(__MODULE__, repo.volume), {:init, workdir(repo), bare?, repo.default_branch})
  end

  @doc """
  Updates the workdir for the given `repo`.
  """
  @spec rename(Repo.t, Repo.t) :: {:ok, Path.t} | {:error, term}
  def rename(%Repo{} = old_repo, %Repo{} = repo) do
    GenServer.call(RepoSupervisor.volume_name(__MODULE__, repo.volume), {:rename, workdir(old_repo), workdir(repo)})
  end

  @doc """
  Removes Git objects and references associated to the given `repo`.
  """
  @spec cleanup(Repo.t) :: {:ok, [Path.t]} | {:error, term}
  def cleanup(%Repo{} = repo) do
    GenServer.call(RepoSupervisor.volume_name(__MODULE__, repo.volume), {:cleanup, workdir(repo)})
  end

  @doc """
  Returns the absolute path to the Git workdir for the given `repo`.

  The path is a concatenation of the Git root path, `repo.owner_login` and `repo.name`.
  """
  @spec workdir(Repo.t) :: Path.t
  def workdir(%Repo{} = repo) do
    Path.join([Keyword.fetch!(Application.get_env(:gitgud, __MODULE__), :git_root), repo.owner_login, repo.name])
  end

  @doc """
  Returns the *VOLUME* identifier.
  """
  @spec volume() :: binary
  def volume, do: GenServer.call(__MODULE__, :volume)

  @doc """
  Ensures the associated volume is tagged.
  """
  @spec ensure_volume_tagged() :: {:ok, binary} | {:error, term}
  def ensure_volume_tagged do
    path = Path.join(Keyword.fetch!(Application.get_env(:gitgud, __MODULE__), :git_root), "VOLUME")
    case File.read(path) do
      {:ok, vol} ->
        {:ok, vol}
      {:error, :enoent} ->
        vol= Base.encode16(:crypto.strong_rand_bytes(4), case: :lower)
        with :ok <- File.mkdir_p(Path.dirname(path)),
             :ok <- File.write(path, vol) do
          {:ok, vol}
        end
      {:error, reason} ->
        {:error, reason}
    end
  end

  #
  # Callbacks
  #

  @impl true
  def init({:volume, vol}) do
    case RepoSupervisor.register_volume(__MODULE__, vol) do
      :ok ->
        {:ok, %{vol: vol}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def handle_call({:init, workdir, bare?, initial_head}, _from, state) do
    {:reply, Git.repository_init(workdir, bare?, initial_head), state}
  end

  def handle_call({:rename, old_workdir, new_workdir}, _from, state) do
    case File.rename(old_workdir, new_workdir) do
      :ok -> {:reply, {:ok, new_workdir}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:cleanup, workdir}, _from, state) do
    {:reply, File.rm_rf(workdir), state}
  end

  def handle_call(:volume, _from, state) do
    {:reply, state.vol, state}
  end
end
