defmodule GitGud.SSHServer do
  @moduledoc """
  Secure Shell (SSH) server providing support for Git server commands.

  The server handles following Git commands:

  * `git-receive-pack` - corresponding server-side command to `git push`.
  * `git-upload-pack` - corresponding server-side command to `git fetch`.

  ## Example

  To process Git commands over SSH, simply start the server as part of your supervision tree:

  ```elixir
  children = [
    Git.SSHServer
  ]

  Supervisor.start_link(children, strategy: :one_for_one)
  ```

  ## Authentication

  A registered `GitGud.User` must authenticate with one of following methods:

  * *public-key* - if any of the associated `GitGud.SSHKey` matches.
  * *password* - if the given credentials are correct.
  * *interactive* - interactive login prompt allowing several tries.

  See `GitGud.Authorization` for more details.
  """

  alias GitGud.Account
  alias GitGud.User
  alias GitGud.UserQuery
  alias GitGud.RepoQuery
  alias GitGud.SSHKey

  alias GitRekt.GitRepo
  alias GitRekt.WireProtocol

  alias GitGud.Authorization

  @behaviour :ssh_server_channel
  @behaviour :ssh_server_key_api

  defstruct [:conn, :chan, :user, :repo, :service, request_size: 0]

  @type t :: %__MODULE__{
    conn: :ssh.connection_ref,
    chan: :ssh.channel_id,
    user: User.t,
    service: module,
    request_size: non_neg_integer
  }

  @doc """
  Returns a child-spec to use as part of a supervision tree.
  """
  @spec child_spec([]) :: Supervisor.Spec.spec
  def child_spec([] = _args) do
    config_opts = Application.get_env(:gitgud, __MODULE__)
    port = Keyword.fetch!(config_opts, :port)
    key_path = Keyword.fetch!(config_opts, :host_key_dir)
    %{id: __MODULE__,
      start: {:ssh, :daemon, [port, daemon_opts(key_path)]},
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
  def is_auth_key(key, login, _opts) do
    if user = UserQuery.by_login(to_string(login), preload: :ssh_keys) do
      fingerprint = to_string(:ssh.hostkey_fingerprint(key))
      if ssh_key = Enum.find(user.ssh_keys, &(&1.fingerprint == fingerprint)) do
        !!SSHKey.update_timestamp!(ssh_key)
      end
    end || false
  end

  @impl true
  def init(_args) do
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_msg({:ssh_channel_up, chan, conn}, state) do
    [user: login] = :ssh.connection_info(conn, [:user])
    {:ok, %{state|conn: conn, chan: chan, user: UserQuery.by_login(to_string(login))}}
  end

  @impl true
  def handle_msg({:EXIT, _port, reason}, state) do
    {:stop, reason, state}
  end

  @impl true
  def handle_ssh_msg({:ssh_cm, conn, {:exec, chan, _reply, cmd}}, %__MODULE__{conn: conn, chan: chan, user: user} = state) do
    case parse_cmd(to_string(cmd)) do
      {:ok, exec, {user_login, repo_name}, _extra_args} ->
        if repo = RepoQuery.user_repo(user_login, repo_name, viewer: user) do
          if authorized?(user, repo, exec) do
            case GitRepo.get_agent(repo) do
              {:ok, agent} ->
                {service, output} = WireProtocol.next(WireProtocol.new(agent, exec, repo: repo))
                :ssh_connection.send(conn, chan, output)
                {:ok, %{state|repo: repo, service: service}}
              {:error, _reason} ->
                {:stop, chan, state}
            end
          else
            {:stop, chan, state}
          end
        else
          {:stop, chan, state}
        end
      :error ->
        {:stop, chan, state}
    end
  end

  @impl true
  def handle_ssh_msg({:ssh_cm, conn, {:data, chan, _type, data}}, %__MODULE__{conn: conn, chan: chan, service: service, request_size: request_size} = state) do
    if request_size <= Application.get_env(:gitgud, :git_max_request_size, :infinity) do
      case WireProtocol.next(service, data) do
        {:cont, service, output} ->
          :ssh_connection.send(conn, chan, output)
          {:ok, %{state|service: service, request_size: request_size + byte_size(data)}}
        {:halt, service, output} ->
          :ssh_connection.send(conn, chan, output)
          :ssh_connection.send_eof(conn, chan)
          {:ok, %{state|service: service, request_size: request_size + byte_size(data)}}
      end
    else
      :ssh_connection.send(conn, chan, 1, "Request entity too large, aborting.\r\n")
      :ssh_connection.send(conn, chan, 0, WireProtocol.encode([:flush]))
      :ssh_connection.send_eof(conn, chan)
      {:stop, chan, state}
    end
  end

  @impl true
  def handle_ssh_msg({:ssh_cm, conn, {:eof, chan}}, %__MODULE__{conn: conn, chan: chan} = state) do
    :ssh_connection.exit_status(conn, chan, 0)
    :ssh_connection.close(conn, chan)
    {:ok, state}
  end

  @impl true
  def handle_ssh_msg({:ssh_cm, conn, {:shell, chan, _reply}}, %__MODULE__{conn: conn, chan: chan} = state) do
    :ssh_connection.send(conn, chan, "You are not allowed to start a shell.\r\n")
    :ssh_connection.send_eof(conn, chan)
    {:stop, chan, state}
  end

  def handle_ssh_msg({:ssh_cm, conn, _msg}, %__MODULE__{conn: conn} = state) do
    {:ok, state}
  end

  @impl true
  def terminate(_reason, _state), do: :ok

  #
  # Helpers
  #

  defp authorized?(user, repo, "git-upload-pack"), do: Authorization.authorized?(user, repo, :pull)
  defp authorized?(user, repo, "git-receive-pack"), do: Authorization.authorized?(user, repo, :push)

  defp daemon_opts(system_dir) do
    [key_cb: {__MODULE__, []},
     ssh_cli: {__MODULE__, []},
     parallel_login: true,
     pwdfun: &check_credentials/2,
     subsystems: [],
     system_dir: to_charlist(system_dir)]
  end

  defp parse_cmd(cmd) do
    [exec|args] = String.split(cmd)
    case parse_args(args) do
      {repo_path, extra_args} ->
        {:ok, exec, repo_path, extra_args}
      nil ->
        :error
    end
  end

  defp parse_args(args) do
    if idx = Enum.find_index(args, &(!String.starts_with?(to_string(&1), "--"))) do
      {path, args} = List.pop_at(args, idx)
      [user_login, repo_name] =
        path
        |> to_string()
        |> String.trim("'")
        |> Path.relative()
        |> Path.split()
      if String.ends_with?(repo_name, ".git") do
        {{user_login, String.slice(repo_name, 0..-5)}, args}
      end
    end
  end

  defp check_credentials(login, password) do
    !!Account.check_credentials(to_string(login), to_string(password))
  end
end
