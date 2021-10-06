defmodule GitRekt.WireProtocol do
  @moduledoc """
  Conveniences for Git transport protocol and server side commands.

  *This module implements version 2 of [Git's wire protocol](https://git-scm.com/docs/protocol-v2).*

  It functions as a very basic finite-state machine by processing incoming client requests
  and forwarding them to the underlying service implementation (respectively `receive-pack` and `upload-pack`).

  The state machine is initialized by calling `new/2` with the Git repository and command to execute.
  By passing incoming data to `next/2`, the underlying service transit to the next state. Once the client and the server
  are done with exchanging Git objects, the service will reach the `:done` state.

  When processing a entire (not chunked), one can use `run/2` to execute all the steps in a single call.
  """

  alias GitRekt.Git
  alias GitRekt.GitAgent
  alias GitRekt.GitRef

  @upload_caps ~w(multi_ack multi_ack_detailed)
  @receive_caps ~w(report-status delete-refs)

  @doc """
  Callback used to transist a service to the next step.
  """
  @callback next(struct, [term]) :: {struct, [term]}

  @doc """
  Callback used to transist a service to the next step without performing any action.
  """
  @callback skip(struct) :: struct

  @doc """
  Returns an *PKT-LINE* encoded representation of the given `lines`.
  """
  @spec encode(Enumerable.t) :: iolist
  def encode(lines) do
    Enum.map(lines, &pkt_line/1)
  end

  @doc """
  Returns a stream of decoded *PKT-LINE*s for the given `pkt`.
  """
  @spec decode(binary) :: Enumerable.t
  def decode(pkt) do
    Stream.map(pkt_stream(pkt), &pkt_decode/1)
  end

  @doc """
  Returns a new service object for the given `repo` and `executable`.
  """
  @spec new(GitAgent.agent, binary, keyword) :: struct
  def new(agent, executable, init_values \\ []) do
    struct(exec_impl(executable), Keyword.put(init_values, :agent, agent))
  end

  @doc """
  Runs the given `service` to the next step.
  """
  @spec next(struct, binary | :discovery) :: {:cont | :halt, struct, iolist}
  def next(service, data \\ :discovery)
  def next(service, :discovery) do
    {service, lines} = exec_next(service, [])
    {service, encode(lines)}
  end

  def next(service, data) do
    if service.state == :buffer do
      {service, lines} = exec_next(service, data)
      exec_after(service, lines)
    else
      {service, lines} = exec_next(service, Enum.to_list(decode(data)))
      exec_after(service, lines)
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
  Returns `true` if `service` is done; elsewise returns `false`.
  """
  @spec done?(struct) :: boolean
  def done?(service), do: service.state == :done

  @doc """
  Returns a stream describing each ref and it current value.
  """
  @spec reference_discovery(GitAgent.agent, binary, [binary]) :: iolist
  def reference_discovery(agent, service, extra_capabilities \\ []) do
    {:ok, refs} = GitAgent.references(agent, target: :commit, stream_chunk_size: :infinity)
    [reference_head(agent)|Enum.to_list(refs)]
    |> List.flatten()
    |> Enum.map(&format_ref_line/1)
    |> List.update_at(0, &(&1 <> "\0" <> Enum.join(server_capabilities(service) ++ extra_capabilities, " ")))
    |> Enum.concat([:flush])
  end

  @doc """
  Returns the given `data` formatted as *PKT-LINE*
  """
  @spec pkt_line(binary|:flush) :: binary
  def pkt_line(data \\ :flush)
  def pkt_line(:flush), do: "0000"
  def pkt_line({:ack, oid}), do: pkt_line("ACK #{Git.oid_fmt(oid)}")
  def pkt_line({:ack, oid, status}), do: pkt_line("ACK #{Git.oid_fmt(oid)} #{status}")
  def pkt_line(:nak), do: pkt_line("NAK")
  def pkt_line(<<"PACK", _rest::binary>> = pack), do: pack
  def pkt_line(data) when is_binary(data) do
    data
    |> byte_size()
    |> Kernel.+(5)
    |> Integer.to_string(16)
    |> String.downcase()
    |> String.pad_leading(4, "0")
    |> Kernel.<>(data)
    |> Kernel.<>("\n")
  end

  @doc false
  def __type__(%{__struct__: GitRekt.WireProtocol.UploadPack}), do: :upload_pack
  def __type__(%{__struct__: GitRekt.WireProtocol.ReceivePack}), do: :receive_pack

  @doc false
  def __service__(:upload_pack), do: GitRekt.WireProtocol.UploadPack
  def __service__(:receive_pack), do: GitRekt.WireProtocol.ReceivePack

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
    ref = make_ref()
    telemetry_start(service, service.state, ref)
    exec_next_state(service, lines, acc, service.state, ref, :os.system_time(:microsecond))
  end

  defp exec_next_state(service, lines, acc, old_state, ref, event_time) do
    case apply(service.__struct__, :next, [service, lines]) do
      {service, [], out} ->
        telemetry_stop(service, old_state, ref, event_time)
        {service, acc ++ out}
      {service, lines, out} ->
        telemetry_next(service, old_state, ref, event_time)
        exec_next_state(service, lines, acc ++ out, service.state, ref, event_time)
    end
  end

  defp exec_after(service, lines) do
    if service.state == :done do
      {service, lines} = exec_next(service, [], lines)
      {:halt, service, encode(lines)}
    else
      {:cont, service, encode(lines)}
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

  defp telemetry_start(_service, state, _ref) when state == :buffer, do: :ok
  defp telemetry_start(service, state, ref) do
    :telemetry.execute([:gitrekt, :wire_protocol, :start], %{}, %{ref: ref, service: __type__(service), state: state})
  end

  defp telemetry_stop(_service, state, _ref, _event_time) when state == :buffer, do: :ok
  defp telemetry_stop(service, state, ref, event_time) do
    :telemetry.execute([:gitrekt, :wire_protocol, :stop], %{duration: :os.system_time(:microsecond) - event_time}, %{ref: ref, service: __type__(service), state: state})
  end

  defp telemetry_next(service, state, _ref, _event_time) when service.state == state, do: :ok
  defp telemetry_next(service, state, ref, event_time) do
    telemetry_stop(service, state, ref, event_time)
    telemetry_start(service, service.state, ref)
  end

  defp server_agent_capability, do: "agent=gitrekt/#{Application.spec(:gitrekt, :vsn)}"

  defp server_capabilities("git-receive-pack"), do: [server_agent_capability()|@receive_caps]
  defp server_capabilities("git-upload-pack"), do: [server_agent_capability()|@upload_caps]

  defp format_ref_line(%GitRef{oid: oid, prefix: prefix, name: name}), do: "#{Git.oid_fmt(oid)} #{prefix <> name}"

  defp reference_head(agent) do
    case GitAgent.head(agent) do
      {:ok, head} -> %{head|prefix: "", name: "HEAD"}
      {:error, _reason} -> []
    end
  end

  defp pkt_stream(data) do
    Stream.resource(fn -> data end, &pkt_next/1, fn _ -> :ok end)
  end

  defp pkt_next(""), do: {:halt, nil}
  defp pkt_next("0000" <> rest), do: {[:flush], rest}
  defp pkt_next("PACK" <> _rest = pack), do: {[{:pack, pack}], ""}
  defp pkt_next(<<hex::bytes-size(4), payload::binary>> = pkt) do
    case Integer.parse(hex, 16) do
      {payload_size, ""} ->
        data_size = payload_size - 4
        data_size_skip_lf = data_size - 1
        case payload do
          <<data::bytes-size(data_size_skip_lf), "\n", rest::binary>> ->
            {[data], rest}
          <<data::bytes-size(data_size), rest::binary>> ->
            {[data], rest}
          <<data::bytes-size(data_size)>> ->
            {[data], ""}
        end
      :error ->
        raise "Invalid PKT line #{inspect pkt}" # TODO
    end
  end

  defp pkt_decode("done"), do: :done
  defp pkt_decode("want " <> hash), do: {:want, hash}
  defp pkt_decode("have " <> hash), do: {:have, hash}
  defp pkt_decode("shallow " <> hash), do: {:shallow, hash}
  defp pkt_decode(pkt_line), do: pkt_line
end
