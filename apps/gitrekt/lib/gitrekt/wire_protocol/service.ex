defmodule GitRekt.WireProtocol.Service do
  @moduledoc """
  Behaviour for implementing Git server-side commands.

  See `GitRekt.WireProtocol.UploadPack` and `GitRekt.WireProtocol.ReceivePack` for more details.
  """

  alias GitRekt.Git

  import GitRekt.WireProtocol, only: [encode: 1, decode: 1]

  @doc """
  Callback used to run and the actual step of a service.
  """
  @callback run(struct) :: {struct, [term]}

  @doc """
  Callback used to transist a service to the next step.
  """
  @callback next(struct, [term]) :: {struct, [term]}

  @doc """
  Returns a new service object for the given `repo` and `executable`.
  """
  @spec new(Git.repo, binary, keyword) :: struct
  def new(repo, executable, opts \\ []) do
    struct(exec_impl(executable), repo: repo, opts: opts)
  end

  @doc """
  Transist the `service` struct to the next state by parsing the given `data`.
  """
  @spec next(struct, binary) :: {struct, iolist}
  def next(service, data) do
    lines = Enum.to_list(decode(data))
    flush(read_all(service, lines))
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

  defp read_all(service, lines) do
    case apply(service.__struct__, :next, [service, lines]) do
      {handle, []} -> handle
      {handle, lines} -> read_all(handle, lines)
    end
  end
end
