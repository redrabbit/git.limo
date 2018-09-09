defmodule GitRekt.WireProtocol do
  @moduledoc """
  Conveniences for Git transport protocol and server side commands.
  """

  alias GitRekt.Git
  alias GitRekt.Packfile
  alias GitRekt.WireProtocol.{Service, ReceivePack, UploadPack}

  @upload_caps ~w(multi_ack multi_ack_detailed)
  @receive_caps ~w(report-status delete-refs)

  @doc """
  Returns a stream describing each ref and it current value.
  """
  @spec reference_discovery(Git.repo, binary) :: iolist
  def reference_discovery(repo, service) do
    [reference_head(repo), reference_list(repo), reference_tags(repo)]
    |> List.flatten()
    |> Enum.map(&format_ref_line/1)
    |> List.update_at(0, &(&1 <> "\0" <> server_capabilities(service)))
    |> Enum.concat([:flush])
  end

  @doc """
  Executes a *git-receive-pack* command on the given `repo`.
  """
  @spec receive_pack(Git.repo, binary | :discovery, keyword) :: {ReceivePack.t, iolist}
  def receive_pack(repo, data \\:discovery, opts \\ []) do
    Service.run(struct(ReceivePack, repo: repo), data, opts)
  end

  @doc """
  Executes a *git-upload-pack* command on the given `repo`.
  """
  @spec upload_pack(Git.repo, binary | :discovery, keyword) :: {UploadPack.t, iolist}
  def upload_pack(repo, data \\:discovery, opts \\ []) do
    Service.run(struct(UploadPack, repo: repo), data, opts)
  end

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
  @spec decode(binary) :: Stream.t
  def decode(pkt) do
    Stream.map(pkt_stream(pkt), &pkt_decode/1)
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

  #
  # Helpers
  #

  defp server_capabilities("git-upload-pack"), do: Enum.join(@upload_caps, " ")
  defp server_capabilities("git-receive-pack"), do: Enum.join(@receive_caps, " ")

  defp format_ref_line({oid, refname}), do: "#{Git.oid_fmt(oid)} #{refname}"

  defp reference_head(repo) do
    case Git.reference_resolve(repo, "HEAD") do
      {:ok, _refname, _shorthand, oid} -> {oid, "HEAD"}
      {:error, _reason} -> []
    end
  end

  defp reference_list(repo) do
    case Git.reference_stream(repo, "refs/heads/*") do
      {:ok, stream} -> Enum.map(stream, fn {refname, _shortand, :oid, oid} -> {oid, refname} end)
      {:error, _reason} -> []
    end
  end

  defp reference_tags(repo) do
    case Git.reference_stream(repo, "refs/tags/*") do
      {:ok, stream} -> Enum.map(stream, &peel_tag_ref(repo, &1))
      {:error, _reason} -> []
    end
  end

  defp peel_tag_ref(repo, {refname, _shorthand, :oid, oid}) do
    with {:ok, :tag, tag} <- Git.object_lookup(repo, oid),
         {:ok, :commit, ^oid, commit} <- Git.tag_peel(tag),
         {:ok, tag_oid} <- Git.object_id(commit) do
      [{tag_oid, refname}, {oid, refname <> "^{}"}]
    else
      {:ok, :commit, _commit} -> {oid, refname}
    end
  end

  defp pkt_stream(data) do
    Stream.resource(fn -> data end, &pkt_next/1, fn _ -> :ok end)
  end

  defp pkt_next(""), do: {:halt, nil}
  defp pkt_next("0000" <> rest), do: {[:flush], rest}
  defp pkt_next("PACK" <> rest), do: Packfile.parse(rest)
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

  defp pkt_decode("done"), do: :done
  defp pkt_decode("want " <> hash), do: {:want, hash}
  defp pkt_decode("have " <> hash), do: {:have, hash}
  defp pkt_decode("shallow " <> hash), do: {:shallow, hash}
  defp pkt_decode(pkt_line), do: pkt_line
end
