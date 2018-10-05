defmodule GitGud.SSHServer do
  @moduledoc """
  Secure Shell (SSH) server providing support for Git server commands.

  The server handles following Git commands:

  * `git-receive-pack` - corresponding server-side command to `git push`.
  * `git-upload-pack` - corresponding server-side command to `git fetch`.

  ## Authentication

  A registered `GitGud.User` can authenticate with following methods:

  * *public-key* - if any of the associated `GitGud.SSHAuthenticationKey` matches.
  * *password* - if the given credentials are correct.
  * *interactive* - interactive login prompt allowing several tries.

  To clone a repository, run following command:

      git clone 'ssh://redrabbit@localhost:8989/USER/REPO'

  ## Authorization

  In order to read and/or write to a repository, a user needs to have the required permissions.

  See `GitGud.Authorization` for more details.
  """

  alias GitGud.User
  alias GitGud.UserQuery

  alias GitGud.Repo
  alias GitGud.RepoQuery

  alias GitRekt.Git
  alias GitRekt.WireProtocol.Service

  alias GitGud.Authorization

  @behaviour :ssh_daemon_channel
  @behaviour :ssh_server_key_api

  defstruct [:conn, :chan, :user, :repo, :service]

  @type t :: %__MODULE__{
    conn: :ssh_connection.ssh_connection_ref,
    chan: :ssh_connection.ssh_channel_id,
    user: User.t,
    service: Module.t
  }

  @doc """
  Returns a child-spec to use as part of a supervision tree.
  """
  @spec child_spec([integer]) :: Supervisor.Spec.spec
  def child_spec([port] = _args) do
    %{id: __MODULE__,
      start: {:ssh, :daemon, [port, daemon_opts()]},
      restart: :permanent,
      shutdown: 5000,
      type: :worker}
  end

  #
  # Callbacks
  #

  @impl true
  def host_key(algo, opts), do: :ssh_file.host_key(algo, opts)

  @impl true
  def is_auth_key(key, username, _opts) do
    user = UserQuery.by_username(to_string(username), preload: :ssh_keys)
    Enum.any?(user.ssh_keys, fn auth ->
      if [{^key, _attrs}] = :public_key.ssh_decode(auth.data, :public_key), do: true
    end)
  end

  @impl true
  def init(_args) do
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_msg({:ssh_channel_up, chan, conn}, state) do
    [user: username] = :ssh.connection_info(conn, [:user])
    {:ok, %{state|conn: conn, chan: chan, user: UserQuery.by_username(to_string(username))}}
  end

  @impl true
  def handle_msg({:EXIT, _port, reason}, state) do
    {:stop, reason, state}
  end

  @impl true
  def handle_ssh_msg({:ssh_cm, conn, {:data, chan, _type, data}}, %__MODULE__{conn: conn, chan: chan, service: service} = state) do
    {service, output} = Service.next(service, data)
    :ssh_connection.send(conn, chan, output)
    if Service.done?(service) do
      {service, output} = Service.next(service)
      :ssh_connection.send(conn, chan, output)
      :ssh_connection.send_eof(conn, chan)
      :ssh_connection.exit_status(conn, chan, 0)
      :ssh_connection.close(conn, chan)
      {:ok, %{state|service: service}}
    else
      {:ok, %{state|service: service}}
    end
  end

  @impl true
  def handle_ssh_msg({:ssh_cm, conn, {:exec, chan, _reply, cmd}}, %__MODULE__{conn: conn, chan: chan, user: user} = state) do
    [exec|args] = String.split(to_string(cmd))
    [repo|_args] = parse_args(args)
    if authorized?(user, repo, exec) do
      {:ok, handle} = Git.repository_open(Repo.workdir(repo))
      {service, output} = Service.next(Service.new(handle, exec, callback: {Repo, :git_push, [repo]}))
      :ssh_connection.send(conn, chan, output)
      {:ok, %{state|repo: repo, service: service}}
    else
      {:stop, chan, state}
    end
  end

  @impl true
  def handle_ssh_msg({:ssh_cm, conn, {:shell, chan, _reply}}, %__MODULE__{conn: conn, chan: chan} = state) do
    :ssh_connection.send(conn, chan, "You are not allowed to start a shell.\r\n")
    :ssh_connection.send_eof(conn, chan)
    {:stop, chan, state}
  end

  @impl true
  def handle_ssh_msg({:ssh_cm, conn, _msg}, %__MODULE__{conn: conn} = state) do
    {:ok, state}
  end

  @impl true
  def terminate(_reason, _state), do: :ok

  #
  # Helpers
  #

  defp authorized?(user, repo, "git-upload-pack"),  do: Authorization.authorized?(user, repo, :read)
  defp authorized?(user, repo, "git-receive-pack"), do: Authorization.authorized?(user, repo, :write)

  defp daemon_opts() do
    system_dir = Path.absname(Application.fetch_env!(:gitgud, :ssh_keys), Application.app_dir(:gitgud))
    [key_cb: {__MODULE__, []},
     ssh_cli: {__MODULE__, []},
     parallel_login: true,
     pwdfun: &check_credentials/2,
     system_dir: to_charlist(system_dir)]
  end

  defp parse_args(args) do
    if idx = Enum.find_index(args, &(!String.starts_with?(to_string(&1), "--"))) do
      {path, args} = List.pop_at(args, idx)
      [RepoQuery.by_path(Path.relative(String.trim(to_string(path), "'")))|args]
    end
  end

  defp check_credentials(username, password) do
    !!User.check_credentials(to_string(username), to_string(password))
  end
end
