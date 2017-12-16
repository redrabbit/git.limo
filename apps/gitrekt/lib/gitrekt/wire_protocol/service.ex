defmodule GitRekt.WireProtocol.Service do
  @moduledoc """
  Behaviour for implementing Git server-side commands.

  See `GitRekt.WireProtocol.UploadPack` and `GitRekt.WireProtocol.ReceivePack` for more details.
  """

  alias GitRekt.Git

  import GitRekt.WireProtocol, only: [encode: 1, decode: 1]

  @callback run(struct) :: {struct, [term]}
  @callback next(struct, [term]) :: {struct, [term]}

  @doc """
  Returns a new service object for the given `repo` and `executable`.
  """
  @spec new(Git.repo, binary) :: struct
  def new(repo, executable) do
    struct(exec_impl(executable), repo: repo)
  end

  @doc """
  Transist the `service` struct to the next state by parsing the given `data`.
  """
  @spec next(struct, binary) :: {struct, iolist}
  def next(service, data) do
    IO.puts "incoming data via #{inspect service}:"
    debug = if byte_size(data) > 1024, do: binary_part(data, 0, 1024), else: data
    IO.binwrite debug
    IO.puts ""

    resp = exec_orig(service.__struct__, Git.repository_get_path(service.repo), data)
    IO.puts "orig response (#{byte_size(resp)}):"
    debug = if byte_size(resp) > 1024, do: binary_part(resp, 0, 1024), else: resp
    IO.binwrite debug
    IO.puts ""

    lines = Enum.to_list(decode(data))
    {service, resp} = flush(read_all(service, lines))
    IO.puts "impl response (#{IO.iodata_length(resp)}):"
    debug = if IO.iodata_length(resp) > 1024, do: binary_part(IO.iodata_to_binary(resp), 0, 1024), else: resp
    IO.binwrite debug
    IO.puts ""
    {service, resp}
  end

  @doc """
  Returns `true` if the service can read more data; elsewhise returns `false`.
  """
  @spec done?(struct) :: boolean
  def done?(service), do: service.state == :done

  @doc """
  Flushes the server response for the given `service` struct.
  """
  @spec flush(Module.t) :: {Module.t, iolist}
  def flush(service) do
    case apply(service.__struct__, :run, [service]) do
      {handle, []} -> {handle, []}
      {handle, io} -> {handle, encode(io)}
    end
  end

  #
  # Helpers
  #

  defp exec_impl("git-upload-pack"),  do: GitRekt.WireProtocol.UploadPack
  defp exec_impl("git-receive-pack"), do: GitRekt.WireProtocol.ReceivePack

  defp exec_orig(GitRekt.WireProtocol.UploadPack, repo_path, request) do
    exec_port("git-upload-pack", repo_path, request)
  end

  defp exec_orig(GitRekt.WireProtocol.ReceivePack, repo_path, request) do
    exec_port("git-receive-pack", repo_path, request)
  end

  defp exec_port(service, repo_path, request) do
    port = Port.open({:spawn, "#{service} --stateless-rpc #{repo_path}"}, [:binary, :exit_status])
    if Port.command(port, request), do: capture_port_output(port)
  end

  defp read_all(service, lines) do
    case apply(service.__struct__, :next, [service, lines]) do
      {handle, []} -> handle
      {handle, lines} -> read_all(handle, lines)
    end
  end

  defp capture_port_output(port, buffer \\ "") do
    receive do
      {^port, {:data, data}} ->
        capture_port_output(port, buffer <> data)
      {^port, {:exit_status, 0}} ->
        buffer
    end
  end
end
