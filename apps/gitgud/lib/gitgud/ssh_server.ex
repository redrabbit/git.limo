defmodule GitGud.SSHServer do
  @moduledoc """
  Secure Shell (SSH) server implemented in pure Erlang/Elixir.
  """

  @behaviour :ssh_daemon_channel
  @behaviour :ssh_server_key_api

  @callback host_key(:ssh.public_key_algorithm, keyword) :: {:ok, :ssh.private_key} | {:error, term}
  @callback execute_cmd(charlist, [charlist]) :: {:ok, port | pid} | {:error, term}
  @callback is_auth_key(:ssh.public_key, charlist, keyword) :: boolean
  @callback is_auth_pwd(charlist, charlist) :: boolean

  defstruct [:conn, :chan, :proc, func: {__MODULE__, :execute_cmd}]

  @type t :: %__MODULE__{
    conn: :ssh_connection.ssh_connection_ref,
    chan: :ssh_connection.ssh_channel_id,
    proc: port | pid,
    func: {module, atom}
  }

  @doc """
  Returns a child-spec to use as part of a supervision tree.
  """
  @spec child_spec([term]) :: Supervisor.Spec.spec
  def child_spec([port]), do: child_spec([port, []])
  def child_spec([port, opts]) when is_list(opts) do
    %{id: __MODULE__,
      start: {:ssh, :daemon, [port, daemon_opts(opts)]},
      restart: :permanent,
      shutdown: 5000,
      type: :worker}
  end

  @doc false
  def is_auth_pwd(_user, _password), do: false

  @doc false
  def execute_cmd(exec, args) do
    exec = :os.find_executable(exec)
    {:ok, Port.open({:spawn_executable, exec}, [args: args] ++ port_opts())}
  end

  #
  # Macros
  #

  defmacro __using__(opts) do
    quote do
      @behaviour unquote(__MODULE__)

      @doc """
      Returns a child-spec to use as part of a supervision tree.
      """
      @spec child_spec([term]) :: Supervisor.Spec.spec
      def child_spec([port]), do: child_spec([port, []])
      def child_spec([port, opts]) when is_list(opts) do
        extra_opts = [
          key_cb: {__MODULE__, []},
          cmdfun: {__MODULE__, :execute_cmd},
          pwdfun: &__MODULE__.is_auth_pwd/2,
        ]
        apply(unquote(__MODULE__), :child_spec, [[port, Keyword.merge(opts, unquote(opts) ++ extra_opts)]])
      end

      defdelegate host_key(algo, opts), to: unquote(__MODULE__)

      defdelegate is_auth_key(key, user, opts), to: unquote(__MODULE__)

      defdelegate is_auth_pwd(user, password), to: unquote(__MODULE__)

      defdelegate execute_cmd(exec, args), to: unquote(__MODULE__)

      defoverridable Module.definitions_in(__MODULE__)
    end
  end

  #
  # Callbacks
  #

  @impl true
  defdelegate host_key(algo, opts), to: :ssh_file

  @impl true
  defdelegate is_auth_key(key, user, opts), to: :ssh_file

  @impl true
  def init(props) do
    {:ok, struct(__MODULE__, props)}
  end

  @impl true
  def handle_msg({:ssh_channel_up, chan, conn}, state) do
    {:ok, struct(state, conn: conn, chan: chan)}
  end

  @impl true
  def handle_msg({proc, {:data, data}}, %__MODULE__{conn: conn, chan: chan, proc: proc} = state) do
    :ssh_connection.send(conn, chan, data)
    {:ok, state}
  end

  @impl true
  def handle_msg({proc, {:exit_status, status}}, %__MODULE__{conn: conn, chan: chan, proc: proc}) do
    :ssh_connection.send_eof(conn, chan)
    :ssh_connection.exit_status(conn, chan, status)
    :ssh_connection.close(conn, chan)
    {:stop, conn, chan}
  end

  @impl true
  def handle_ssh_msg({:ssh_cm, conn, {:data, chan, _type, data}}, %__MODULE__{conn: conn, chan: chan, proc: pid} = state) when is_pid(pid) do
    send(pid, {:ssh, self(), {:data, data}})
    {:ok, state}
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
  def handle_ssh_msg({:ssh_cm, conn, {:exec, chan, _reply, cmd}}, %__MODULE__{conn: conn, chan: chan, func: {mod, fun}} = state) do
    [exec|args] = Enum.map(String.split(to_string(cmd)), &to_charlist/1)
    case apply(mod, fun, [exec, args]) do
      {:ok, proc} ->
        {:ok, struct(state, proc: proc)}
      {:error, :invalid_exec} ->
        :ssh_connection.send(conn, chan, "You are not allowed to execute \"#{exec}\".\r\n")
        :ssh_connection.send_eof(conn, chan)
        {:stop, chan, state}
    end
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

  defp daemon_opts(opts) do
    {mod, opts} = Keyword.pop(opts, :cmdfun)
    if is_nil(mod),
      do: Keyword.merge([ssh_cli: {__MODULE__, []}], opts),
    else: Keyword.merge([ssh_cli: {__MODULE__, func: mod}], opts)
  end

  defp port_opts() do
    [:stream, :binary, :exit_status, :use_stdio, :stderr_to_stdout]
  end
end
