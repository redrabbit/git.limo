defmodule GitRekt.WireProtocol do
  @moduledoc """
  Conveniences for Git transport protocol and server side commands.
  """

  alias GitRekt.Git
  alias GitRekt.Packfile

  @upload_caps ~w()
  @receive_caps ~w(report-status delete-refs)

  @doc """
  Returns a *PKT-LINE* stream describing each ref and it current value.
  """
  @spec reference_discovery(Git.repo, binary) :: [binary]
  def reference_discovery(repo, service) do
    [reference_head(repo), reference_list(repo), reference_tags(repo)]
    |> List.flatten()
    |> Enum.map(&format_ref_line/1)
    |> List.update_at(0, &(&1 <> "\0" <> server_capabilities(service)))
    |> Enum.map(&pkt_line/1)
    |> Enum.concat([pkt_line()])
  end

  @doc """
  Sends objects packed back to *git-fetch-pack*.
  """
  @spec upload_pack(Git.repo, binary) :: binary
  def upload_pack(repo, pkt) do
    case parse_upload_pkt(pkt) do
      {:done, wants, _shallows, _haves, _caps} ->
        encode(["NAK", Packfile.create(repo, wants)])
    end
  end

  @doc """
  Receives what is pushed into the repository.
  """
  @spec receive_pack(Git.repo, binary) :: binary
  def receive_pack(repo, pkt) do
    {refs, pack, caps} = parse_receive_pkt(pkt)
    {:ok, odb} = Git.repository_get_odb(repo)
    Enum.each(pack, &apply_pack_obj(odb, &1))
    Enum.each(refs, &rename_ref(repo, &1))
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
    Stream.map(pkt_stream(pkt), &pkt_decode/1)
  end

  @doc """
  Returns the given `data` formatted as *PKT-LINE*
  """
  @spec pkt_line(binary|:flush) :: binary
  def pkt_line(data \\ :flush)
  def pkt_line(:flush), do: "0000"
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
      {:ok, :commit, _commit} ->
        {oid, refname}
    end
  end

  defp rename_ref(repo, {_old_oid, new_oid, refname}) do
    Git.reference_create(repo, refname, :oid, new_oid, true)
  end

  defp apply_pack_obj(odb, {:delta_reference, {base_oid, _base_obj_size, _result_obj_size, cmds}}) do
    {:ok, obj_type, obj_data} = Git.odb_read(odb, base_oid)
    new_data = apply_delta_chain(obj_data, "", cmds)
    {:ok, _oid} = apply_pack_obj(odb, {obj_type, new_data})
  end

  defp apply_pack_obj(odb, {obj_type, obj_data}) do
    {:ok, _oid} = Git.odb_write(odb, obj_data, obj_type)
  end

  defp apply_delta_chain(_source, target, []), do: target
  defp apply_delta_chain(source, target, [{:insert, chunk}|cmds]) do
    apply_delta_chain(source, target <> chunk, cmds)
  end

  defp apply_delta_chain(source, target, [{:copy, {offset, size}}|cmds]) do
    apply_delta_chain(source, target <> binary_part(source, offset, size), cmds)
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
  defp pkt_decode(pkt_line), do: pkt_line

  defp parse_upload_pkt(pkt) do
    lines = decode(pkt)
    {wants, lines} = Enum.split_while(lines, &upload_line_type?(&1, :want))
    {wants, capabilities} = parse_upload_caps(wants)
    {shallows, lines} = Enum.split_while(lines, &upload_line_type?(&1, :shallow))
    [:flush|lines] = lines
    {haves, lines} = Enum.split_while(lines, &upload_line_type?(&1, :have))
    [last_line] = lines
    {last_line, format_cmd_lines(wants), format_cmd_lines(shallows), format_cmd_lines(haves), capabilities}
  end

  defp parse_upload_caps([{obj_type, first_ref}|wants]) do
    case String.split(first_ref, "\0", parts: 2) do
      [first_ref]       -> {[{obj_type, first_ref}|wants], []}
      [first_ref, caps] -> {[{obj_type, first_ref}|wants], String.split(caps, " ", trim: true)}
    end
  end

  defp parse_receive_pkt(pkt) do
    lines = decode(pkt)
    {refs, lines} = Enum.split_while(lines, &is_binary/1)
    {refs, capabilities} = parse_receive_caps(refs)
    [:flush|pack] = lines
    {Enum.map(refs, &parse_receive_ref/1), pack, capabilities}
  end

  defp parse_receive_caps([first_ref|refs]) do
    case String.split(first_ref, "\0", parts: 2) do
      [first_ref]       -> {[first_ref|refs], []}
      [first_ref, caps] -> {[first_ref|refs], String.split(caps, " ", trim: true)}
    end
  end

  defp parse_receive_ref(ref) do
    [old, new, name] = String.split(ref)
    {Git.oid_parse(old), Git.oid_parse(new), name}
  end

  defp upload_line_type?({type, _oid}, type), do: true
  defp upload_line_type?(_line, _type), do: false

  defp format_ref_line({oid, refname}), do: "#{Git.oid_fmt(oid)} #{refname}"
  defp format_cmd_lines(lines), do: Enum.uniq(Enum.map(lines, &Git.oid_parse(elem(&1, 1))))
end
