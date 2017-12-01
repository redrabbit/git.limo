defmodule GitRekt.WireProtocol do
  @moduledoc """
  Conveniences for Git transport protocol and server side commands.
  """

  alias GitRekt.Git
  alias GitRekt.Pack

  @server_capabilities ~w(report-status)

  @doc """
  Returns a *PKT-LINE* stream describing each ref and it current value.
  """
  @spec reference_discovery(Git.repo) :: [binary]
  def reference_discovery(repo) do
    [reference_head(repo)|reference_list(repo)]
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&format_ref_line/1)
    |> List.update_at(0, &(&1 <> "\0" <> server_capabilities()))
    |> Enum.map(&pkt_line/1)
    |> Enum.concat([pkt_line()])
  end

  @doc """
  Sends objects packed back to *git-fetch-pack*.
  """
  @spec upload_pack(Git.repo, binary) :: binary
  def upload_pack(repo, pkt) do
    {[oid|_], _lines} = parse_upload_pkt(pkt)
    encode(["NAK", Pack.create(repo, oid)])
  end

  @doc """
  Receives what is pushed into the repository.
  """
  @spec receive_pack(Git.repo, binary) :: binary
  def receive_pack(repo, pkt) do
    {refs, pack, caps} = parse_receive_pkt(pkt)
    {:ok, odb} = Git.repository_get_odb(repo)
    Enum.each(pack, fn {obj_type, obj_data} -> {:ok, _} = Git.odb_write(odb, obj_data, obj_type) end)
    Enum.each(refs, fn {_old_oid, new_oid, refname} -> :ok = Git.reference_create(repo, refname, :oid, new_oid, true) end)
    if "report-status" in caps,
      do: encode(["unpack ok", Enum.into(refs, "", &"ok #{elem(&1, 2)}"), :flush]),
    else: []
  end

  @doc """
  Returns an *PKT-LINE* encoded representation of the given `lines`.
  """
  @spec encode(Enumerable.t) :: [binary]
  def encode(lines) do
    Enum.map(lines, &pkt_line/1)
  end

  @doc """
  Returns a stream of decoded *PKT-LINE*s for the given `pkt`.
  """
  @spec decode(binary) :: Stream.t
  def decode(pkt) do
    Stream.map(pkt_stream(pkt), &pkt_transform/1)
  end

  @doc """
  Returns the given `data` formatted as *PKT-LINE*
  """
  @spec pkt_line(binary|:flush) :: binary
  def pkt_line(data \\ :flush)
  def pkt_line(:flush), do: "0000"
  def pkt_line(<<"PACK", _rest::binary>> = pack), do: pack
  def pkt_line(data) do
    data
    |> byte_size()
    |> Kernel.+(5)
    |> Integer.to_string(16)
    |> String.downcase()
    |> String.pad_leading(4, "0")
    |> Kernel.<>(data)
    |> Kernel.<>("\n")
  end

  #
  # Helpers
  #

  defp server_capabilities, do: Enum.join(@server_capabilities, " ")

  defp reference_head(repo) do
    case Git.reference_resolve(repo, "HEAD") do
      {:ok, _refname, _shorthand, oid} -> {oid, "HEAD"}
      {:error, _reason} -> nil
    end
  end

  defp reference_list(repo) do
    case Git.reference_stream(repo) do
      {:ok, stream} -> Enum.map(stream, fn {refname, _shortand, :oid, oid} -> {oid, refname} end)
      {:error, _reason} -> []
    end
  end

  defp pkt_stream(data) do
    Stream.resource(fn -> data end, &pkt_next/1, fn _ -> :ok end)
  end

  defp pkt_next(""), do: {:halt, nil}
  defp pkt_next("0000" <> rest), do: {[:flush], rest}
  defp pkt_next(<<"PACK", version::32, count::32, data::binary>>), do: Pack.extract(version, count, data)
  defp pkt_next(<<hex::bytes-size(4), payload::binary>>) do
    {payload_size, ""} = Integer.parse(hex, 16)
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
  end

  defp pkt_transform("done"), do: :done
  defp pkt_transform("want " <> hash), do: {:want, Git.oid_parse(hash)}
  defp pkt_transform("ACK"), do: :ack
  defp pkt_transform("NAK"), do: :neg_ack
  defp pkt_transform(pkt_line), do: pkt_line

  defp parse_upload_pkt(pkt) do
    [wants|lines] = Enum.reject(Enum.chunk_by(decode(pkt), &(&1 == :flush)), &(&1 == [:flush]))
    {parse_upload_refs(wants), lines}
  end

  defp parse_upload_refs(wants) do
    wants
    |> Enum.filter(fn {:want, _oid} -> true; _ -> false end)
    |> Enum.map(&elem(&1, 1))
    |> Enum.uniq()
  end

  defp parse_receive_pkt(pkt) do
    [refs|pack] = Enum.reject(Enum.chunk_by(decode(pkt), &(&1 == :flush)), &(&1 == [:flush]))
    [first_ref|refs] = refs
    [first_ref, caps] = String.split(first_ref, "\0", parts: 2)
    {Enum.map([first_ref|refs], &parse_receive_ref/1), pack, String.split(caps, " ", trim: true)}
  end

  defp parse_receive_ref(ref) do
    [old, new, name] = String.split(ref)
    {Git.oid_parse(old), Git.oid_parse(new), name}
  end

  defp format_ref_line({oid, refname}), do: "#{Git.oid_fmt(oid)} #{refname}"
end
