defmodule GitRekt.Packfile do
  @moduledoc """
  Conveniences for reading and writting Git pack files.
  """

  import Bitwise

  alias GitRekt.Git

  @type obj       :: {Git.obj_type, binary}
  @type obj_iter  :: {non_neg_integer, non_neg_integer, binary}

  @doc """
  Returns a list of ODB objects and their type for the given *PACK* `data`.
  """
  @spec parse(binary) :: {:pack, [obj]} | {:buffer, [obj], obj_iter}
  def parse("PACK" <> pack), do: parse(pack)
  def parse(<<version::32, count::32, data::binary>> = _pack), do: unpack(version, count, data)

  @doc """
  Same as `parse/1` but starts from the given `iterator`.
  """
  @spec parse(binary, obj_iter) :: {:pack, [obj]} | {:buffer, [obj], obj_iter}
  def parse(pack, iterator) when is_list(pack), do: parse(IO.iodata_to_binary(pack), iterator)
  def parse(pack, {0, 0, ""} = _iterator) when is_binary(pack), do: parse(pack)
  def parse(pack, {i, max, rest} = _iterator) when is_binary(pack), do: unpack_obj_next(i, max, rest <> pack, [])

  @doc """
  Returns the *PACK* version and the number of objects it contains.
  """
  @spec parse_header(binary) :: {2, non_neg_integer}
  def parse_header("PACK" <> pack), do: parse_header(pack)
  def parse_header(<<version::32, count::32, _rest::binary>> = _pack), do: {version, count}

  #
  # Helpers
  #

  defp unpack(2 = _version, count, data) do
    unpack_obj_next(0, count, data, [])
  end

  defp unpack_obj_next(i, max, rest, acc) when i < max do
    case unpack_obj(rest) do
      {obj_type, obj, rest} ->
        unpack_obj_next(i+1, max, rest, [{obj_type, obj}|acc])
      :need_more ->
        {:buffer, Enum.reverse(acc), {i, max, rest}}
    end
  end

  defp unpack_obj_next(max, max, <<_checksum::binary-20>>, acc), do: {:pack, Enum.reverse(acc)}

  defp unpack_obj(data) when byte_size(data) > 2 do
    {id_type, inflate_size, rest} = unpack_obj_head(data)
    obj_type = format_obj_type(id_type)
    cond do
      obj_type == :delta_reference && byte_size(rest) > 20 ->
        <<base_oid::binary-20, rest::binary>> = rest
        {delta, rest} = unpack_obj_data(rest)
        if byte_size(delta) < inflate_size,
          do: :need_more,
        else: {obj_type, unpack_obj_delta(base_oid, delta), rest}
      obj_type == :delta_reference ->
        :need_more
      true ->
        {obj_data, rest} = unpack_obj_data(rest)
        if byte_size(obj_data) < inflate_size,
          do: :need_more,
        else: {obj_type, obj_data, rest}
    end
  end

  defp unpack_obj(_data), do: :need_more

  defp unpack_obj_head(<<0::1, type::3, num::4, rest::binary>>), do: {type, num, rest}
  defp unpack_obj_head(<<1::1, type::3, num::4, rest::binary>>) do
    {size, rest} = unpack_obj_size(rest, num, 0)
    {type, size, rest}
  end

  defp unpack_obj_size(<<0::1, num::7, rest::binary>>, acc, i), do: {acc + (num <<< 4+7*i), rest}
  defp unpack_obj_size(<<1::1, num::7, rest::binary>>, acc, i) do
    unpack_obj_size(rest, acc + (num <<< (4+7*i)), i+1)
  end

  defp unpack_obj_data(data) do
    data_size = byte_size(data)
    case Git.object_zlib_inflate(data) do
      {:ok, chunks, deflate_size} ->
        if data_size < deflate_size,
          do: {"", data},
        else: {IO.iodata_to_binary(chunks), binary_part(data, deflate_size, data_size-deflate_size)}
      {:error, _reason} ->
        {"", data}
    end
  end

  defp unpack_obj_delta(base_oid, delta) do
    {base_obj_size, rest} = unpack_obj_delta_size(delta, 0, 0)
    {result_obj_size, rest} = unpack_obj_delta_size(rest, 0, 0)
    {base_oid, base_obj_size, result_obj_size, unpack_obj_delta_hunk(rest, [])}
  end

  defp unpack_obj_delta_size(<<0::1, num::7, rest::binary>>, acc, i), do: {acc ||| (num <<< 7*i), rest}
  defp unpack_obj_delta_size(<<1::1, num::7, rest::binary>>, acc, i) do
    unpack_obj_delta_size(rest, acc ||| (num <<< 7*i), i+1)
  end

  defp unpack_obj_delta_hunk(<<0::1, size::7, data::binary-size(size), rest::binary>>, cmds) do
    unpack_obj_delta_hunk(rest, [{:insert, data}|cmds])
  end

  defp unpack_obj_delta_hunk(<<copy_instruction::size(8), rest::binary>>, cmds) do
    {offset, size, rest} = delta_copy_range(copy_instruction, rest)
    unpack_obj_delta_hunk(rest, [{:copy, {offset, size}}|cmds])
  end

  defp unpack_obj_delta_hunk("", cmds), do: Enum.reverse(cmds)

  defp delta_copy_range(x, rest) do
    offset = 0
    size = 0

    {offset, rest} =
      if (x &&& 0x01) > 0 do
        <<c::size(8), rest::binary>> = rest
        {c, rest}
      end || {offset, rest}

    {offset, rest} =
      if (x &&& 0x02) > 0 do
        <<c::size(8), rest::binary>> = rest
        {offset ||| (c <<< 8), rest}
      end || {offset, rest}

    {offset, rest} =
      if (x &&& 0x04) > 0 do
        <<c::size(8), rest::binary>> = rest
        {offset ||| (c <<< 16), rest}
      end || {offset, rest}

    {offset, rest} =
      if (x &&& 0x08) > 0 do
        <<c::size(8), rest::binary>> = rest
        {offset ||| (c <<< 24), rest}
      end || {offset, rest}

    {size, rest} =
      if (x &&& 0x10) > 0 do
        <<c::size(8), rest::binary>> = rest
        {c, rest}
      end || {size, rest}

    {size, rest} =
      if (x &&& 0x20) > 0 do
        <<c::size(8), rest::binary>> = rest
        {size ||| (c <<< 8), rest}
      end || {size, rest}

    {size, rest} =
      if (x &&& 0x40) > 0 do
        <<c::size(8), rest::binary>> = rest
        {size ||| (c <<< 16), rest}
      end || {size, rest}

    size =
      if size == 0,
        do: 0x10000,
      else: size

    {offset, size, rest}
  end

  defp format_obj_type(1), do: :commit
  defp format_obj_type(2), do: :tree
  defp format_obj_type(3), do: :blob
  defp format_obj_type(4), do: :tag
  defp format_obj_type(6), do: :delta_offset
  defp format_obj_type(7), do: :delta_reference
end
