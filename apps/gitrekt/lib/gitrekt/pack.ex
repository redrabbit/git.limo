defmodule GitRekt.Pack do
  @moduledoc """
  Conveniences for reading and writting Git pack files.
  """

  alias GitRekt.Git

  @type obj :: {obj_type, binary}
  @type obj_type :: :commit | :tree | :blob | :tag

  @doc """
  Returns a *PACK* file for the given `oid`.
  """
  @spec create(Git.repo, Git.oid) :: binary
  def create(repo, oid) do
    with {:ok, walk} <- Git.revwalk_new(repo),
          :ok <- Git.revwalk_push(walk, oid),
         {:ok, pack} = Git.revwalk_pack(walk), do: pack
  end

  @doc """
  Returns a list of ODB objects and their type for the given *PACK* file `data`.
  """
  @spec extract(2, non_neg_integer, binary) :: {[obj], binary}
  def extract(2 = _version, count, data) do
    unpack_obj_next(0, count, data, [])
  end

  #
  # Helpers
  #

  defp unpack_obj_next(i, max, rest, acc) when i < max do
    {obj_type, obj, rest} = unpack_obj(rest)
    unpack_obj_next(i+1, max, rest, [{obj_type, obj}|acc])
  end

  defp unpack_obj_next(max, max, rest, acc) do
    <<_checksum::binary-20, rest::binary>> = rest
    {Enum.reverse(acc), rest}
  end

  defp unpack_obj(data) do
    {id_type, _inflate_size, rest} = unpack_obj_head(data)
    obj_type = format_obj_type(id_type)
    cond do
      obj_type == :delta_reference ->
        <<obj_name::binary-20, rest::binary>> = rest
        {obj_data, rest} = unpack_obj_data(rest)
        {obj_type, {obj_name, obj_data}, rest}
      obj_type == :delta_offset ->
        raise ArgumentError, "Blob delta offset length not calculated"
      true ->
        {obj_data, rest} = unpack_obj_data(rest)
        {obj_type, obj_data, rest}
    end
  end

  defp unpack_obj_head(<<0::1, type::3, size::4, rest::binary>>) do
    {type, size, rest}
  end

  defp unpack_obj_head(<<1::1, type::3, obj_num::bitstring-4, rest::binary>>) do
    {size, rest} = unpack_obj_size(rest, obj_num)
    {type, size, rest}
  end

  defp unpack_obj_size(<<0::1, obj_num::bitstring-7, rest::binary>>, acc_num) do
    with acc <- <<acc_num::bitstring, obj_num::bitstring>>,
         len <- bit_size(acc),
       <<num::integer-size(len)>> <- acc, do: {num, rest}
  end

  defp unpack_obj_size(<<1::1, obj_num::bitstring-7, rest::binary>>, acc_num) do
    unpack_obj_size(rest, <<acc_num::bitstring, obj_num::bitstring>>)
  end

  defp unpack_obj_data(data) do
    {:ok, obj, deflate_size} = Git.object_zlib_inflate(data)
    {obj, binary_part(data, deflate_size, byte_size(data)-deflate_size)}
  end

  defp format_obj_type(1), do: :commit
  defp format_obj_type(2), do: :tree
  defp format_obj_type(3), do: :blob
  defp format_obj_type(4), do: :tag
  defp format_obj_type(6), do: :delta_offset
  defp format_obj_type(7), do: :delta_reference

end
