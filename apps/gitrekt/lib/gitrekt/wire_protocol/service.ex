defmodule GitRekt.WireProtocol.Service do
  @moduledoc """
  Behaviour for implementing Git server-side commands.

  See `GitRekt.WireProtocol.UploadPack` and `GitRekt.WireProtocol.ReceivePack` for more details.
  """

  alias GitRekt.Git

  import GitRekt.WireProtocol, only: [encode: 1, decode: 1]

  @doc """
  Callback used to transist a service to the next step.
  """
  @callback next(struct, [term]) :: {struct, [term]}

  @doc """
  Returns a new service object for the given `repo` and `executable`.
  """
  @spec new(Git.repo, binary) :: struct
  def new(repo, executable) do
    struct(exec_impl(executable), repo: repo)
  end

  @doc """
  Runs the given `service` to the next step.
  """
  @spec next(struct, binary) :: {struct, iolist}
  def next(service, data \\ :discovery)
  def next(service, data) when is_binary(data) do
    {service, lines} = exec_next(service, Enum.to_list(decode(data)))
    {service, encode(lines)}
  end

  def next(service, :discovery) do
    {service, lines} = exec_next(service, [])
    {service, encode(lines)}
  end

  @doc """
  Runs all the steps of the given `service` at once.
  """
  @spec run(struct, binary) :: {struct, iolist}
  def run(service, data \\ :discovery)
  def run(service, data) when is_binary(data) do
    {service, lines} = exec_all(service, Enum.to_list(decode(data)))
    {service, encode(lines)}
  end

  def run(service, :discovery) do
    {service, lines} = exec_all(service, [])
    {service, encode(lines)}
  end

  @doc """
  Returns `true` if `service` is done; elsewhise returns `false`.
  """
  @spec done?(struct) :: boolean
  def done?(service), do: service.state == :done

  #
  # Helpers
  #

  defp exec_next(service, lines, acc \\ []) do
    case apply(service.__struct__, :next, [service, lines]) do
      {service, [], out} -> {service, acc ++ out}
      {service, lines, out} -> exec_next(service, lines, acc ++ out)
    end
  end

  defp exec_all(service, lines, acc \\ []) do
    done? = done?(service)
    {service, out} = exec_next(service, lines)
    if done?, do: {service, acc ++ out}, else: exec_all(service, [], acc ++ out)
  end

  defp exec_impl("git-upload-pack"),  do: GitRekt.WireProtocol.UploadPack
  defp exec_impl("git-receive-pack"), do: GitRekt.WireProtocol.ReceivePack
end
