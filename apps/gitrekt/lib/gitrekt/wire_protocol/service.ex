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
  Callback used to transist a service to the next step without performing any action.
  """
  @callback skip(struct) :: struct

  @doc """
  Returns a new service object for the given `repo` and `executable`.
  """
  @spec new(Git.repo, binary) :: struct
  def new(repo, executable, init_values \\ []) do
    struct(exec_impl(executable), Keyword.put(init_values, :repo, repo))
  end

  @doc """
  Runs the given `service` to the next step.
  """
  @spec next(struct, binary | :discovery) :: {struct, iolist}
  def next(service, data \\ :discovery)
  def next(service, :discovery) do
    {service, lines} = exec_next(service, [])
    {service, encode(lines)}
  end

  def next(service, data) do
    if service.state == :buffer do
      {service, lines} = exec_next(service, data)
      {service, encode(lines)}
    else
      {service, lines} = exec_next(service, Enum.to_list(decode(data)))
      {service, encode(lines)}
    end
  end

  @doc """
  Runs all the steps of the given `service` at once.
  """
  @spec run(struct, binary | :discovery, keyword) :: {struct, iolist}
  def run(service, data \\ :discovery, opts \\ [])
  def run(service, :discovery, opts), do: exec_run(service, [], opts)
  def run(service, data, opts), do: exec_run(service, Enum.to_list(decode(data)), opts)

  @doc """
  Sets the given `service` to the next logical step without performing any action.
  """
  @spec skip(struct) :: struct
  def skip(service), do: apply(service.__struct__, :skip, [service])

  @doc """
  Returns `true` if `service` is done; elsewhise returns `false`.
  """
  @spec done?(struct) :: boolean
  def done?(service), do: service.state == :done

  #
  # Helpers
  #

  defp exec_run(service, lines, opts) do
    {service, _skip} =
      if skip = Keyword.get(opts, :skip),
        do: exec_skip(service, skip),
      else: service
    {service, lines} = exec_all(service, lines)
    {service, encode(lines)}
  end

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

  defp exec_skip(service, count) when count > 0 do
    Enum.reduce(1..count, {service, []}, fn _i, {service, states} ->
      {skip(service), [service.state|states]}
    end)
  end

  defp exec_impl("git-upload-pack"),  do: GitRekt.WireProtocol.UploadPack
  defp exec_impl("git-receive-pack"), do: GitRekt.WireProtocol.ReceivePack
end
