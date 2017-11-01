defmodule GitGud.SSHServer do
  @moduledoc """
  Secure Shell (SSH) server providing support for Git server commands.

  In the current implementation, the server is restricted to the following Git commands:

  * `git-receive-pack` - corresponding server-side command to `git push`.
  * `git-upload-pack` - corresponding server-side command to `git fetch`.
  * `git-upload-archive` - corresponding server-side command to `git archive`.

  A port is spawned for each running command. *In future implementations, the server might support those commands natively*.

  ## Authentication

  User authentication is handled by the application, it does not depend on available users on the machine.

  A registered `GitGud.User` can authenticate with following methods:

  * *public-key* - if any of the associated `GitGud.SSHAuthenticationKey` matches.
  * *password* - if the given user credentials are correct.
  * *interactive* - interactive login prompt allowing several tries.

  For example, to clone a repository you would run following command:

      git clone 'ssh://redrabbit@localhost:8989/USER/REPO'

  ## Authorization

  In order to read and/or write to a repository, a user needs to have the required permissions.

  See `GitGud.Repo.can_read?/2` and `GitGud.Repository.can_write?/2` for more details.
  """

  alias GitGud.User
  alias GitGud.UserQuery

  alias GitGud.Repo
  alias GitGud.RepoQuery

  @behaviour :ssh_daemon_channel
  @behaviour :ssh_server_key_api

  @root_path Application.fetch_env!(:gitgud, :git_dir)

  defstruct [:conn, :chan, :user, :proc]

  @type t :: %__MODULE__{
    conn: :ssh_connection.ssh_connection_ref,
    chan: :ssh_connection.ssh_channel_id,
    proc: port,
  }

  @doc """
  Returns a child-spec to use as part of a supervision tree.
  """
  @spec child_spec([integer]) :: Supervisor.Spec.spec
  def child_spec([port]) do
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
  defdelegate host_key(algo, opts), to: :ssh_file

  @impl true
  def is_auth_key(key, username, _opts) do
    user = UserQuery.get(to_string(username), preload: :authentication_keys)
    Enum.any?(user.authentication_keys, fn auth ->
      if [{^key, _attrs}] = :public_key.ssh_decode(auth.key, :public_key), do: true
    end)
  end

  @impl true
  def init(_args) do
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_msg({:ssh_channel_up, chan, conn}, state) do
    [user: username] = :ssh.connection_info(conn, [:user])
    {:ok, struct(state, conn: conn, chan: chan, user: UserQuery.get(to_string(username)))}
  end

  @impl true
  def handle_msg({proc, {:data, data}}, %__MODULE__{conn: conn, chan: chan, proc: proc} = state) when is_port(proc) do
    :ssh_connection.send(conn, chan, data)
    {:ok, state}
  end

  @impl true
  def handle_msg({proc, {:exit_status, status}}, %__MODULE__{conn: conn, chan: chan, proc: proc}) when is_port(proc) do
    :ssh_connection.send_eof(conn, chan)
    :ssh_connection.exit_status(conn, chan, status)
    :ssh_connection.close(conn, chan)
    {:stop, conn, chan}
  end

  @impl true
  def handle_ssh_msg({:ssh_cm, conn, {:data, chan, _type, data}}, %__MODULE__{conn: conn, chan: chan, proc: proc} = state) when is_port(proc) do
    :erlang.port_command(proc, data)
    {:ok, state}
  end

  @impl true
  def handle_ssh_msg({:ssh_cm, conn, {:exec, chan, _reply, cmd}}, %__MODULE__{conn: conn, chan: chan, user: user} = state) do
    [exec|args] = Enum.map(String.split(to_string(cmd)), &to_charlist/1)
    case execute_cmd(exec, args, user) do
      {:ok, proc} ->
        {:ok, struct(state, proc: proc)}
      {:error, :unauthorized} ->
        :ssh_connection.send_eof(conn, chan)
        :ssh_connection.exit_status(conn, chan, 401)
        {:stop, chan, state}
    end
  end

  @impl true
  def handle_ssh_msg({:ssh_cm, conn, {:data, chan, _type, data}}, %__MODULE__{conn: conn, chan: chan, proc: proc} = state) when is_port(proc) do
    :erlang.port_command(proc, data)
    {:ok, state}
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

  defp daemon_opts() do
    system_dir = Application.fetch_env!(:gitgud, :ssh_system_dir)
    [key_cb: {__MODULE__, []},
     ssh_cli: {__MODULE__, []},
     parallel_login: true,
     pwdfun: &check_credentials/2,
     system_dir: to_charlist(system_dir)]
  end

  defp port_opts() do
    [:stream, :binary, :exit_status]
  end

  defp resolve_repo(user, path) do
    relpath = Path.relative_to(to_string(path), Path.join(@root_path, user.username))
    RepoQuery.user_repository(user, relpath)
  end

  defp check_credentials(username, password) do
    !!User.check_credentials(to_string(username), to_string(password))
  end

  defp has_permission?(user, path, exec) when exec == 'git-receive-pack' do
    Repo.can_write?(user, resolve_repo(user, path))
  end

  defp has_permission?(user, path, exec) when exec in ['git-upload-pack', 'git-upload-archive'] do
    Repo.can_read?(user, resolve_repo(user, path))
  end

  defp has_permission?(_username, _path, _exec), do: false

  defp execute_cmd(exec, args, user) do
    [path|args] = extract_path(args)
    if has_permission?(user, path, exec),
      do: {:ok, Port.open({:spawn_executable, :os.find_executable(exec)}, [args: [path|args]] ++ port_opts())},
    else: {:error, :unauthorized}
  end

  defp extract_path(args) do
    if idx = Enum.find_index(args, &(!String.starts_with?(to_string(&1), "--"))) do
      {path, args} = List.pop_at(args, idx)
      abspath = Path.join(@root_path, String.trim(to_string(path), "'"))
      [to_charlist(abspath)|args]
    else
      [nil|args]
    end
  end
end
