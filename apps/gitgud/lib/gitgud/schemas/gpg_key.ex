defmodule GitGud.GPGKey do
  @moduledoc """
  GNU Privacy Guard (GPG) key schema and helper functions.
  """

  use Ecto.Schema

  alias GitGud.DB
  alias GitGud.User

  import Ecto.Changeset

  schema "gpg_keys" do
    belongs_to :user, User
    field :data, :string, virtual: true
    field :key_id, :binary
    field :sub_keys, {:array, :binary}
    field :emails, {:array, :string}
    timestamps(updated_at: false)
    field :expires_at, :naive_datetime
  end

  @type t :: %__MODULE__{
    id: pos_integer,
    user_id: pos_integer,
    user: User.t,
    data: binary,
    key_id: binary,
    inserted_at: NaiveDateTime.t,
  }

  @packet_types %{
    0 => :reserved, # Reserved
    1 => :pkesk, # Public-Key Encrypted Session Key Packet
    2 => :sig, # Signature Packet
    3 => :skesk, # Symmetric-Key Encrypted Session Key Packet
    4 => :opsig, # One-Pass Signature Packet
    5 => :seck, # Secret-Key Packet
    6 => :pubk, # Public-Key Packet
    7 => :secsubk, # Secret-Subkey Packet
    8 => :cdata, # Compressed Data Packet
    9 => :sedata, # Symmetrically Encrypted Data Packet
    10 => :marker, # Marker Packet
    11 => :ldata, # Literal Data Packet
    12 => :trust, # Trust Packet
    13 => :uid, # User ID Packet
    14 => :pubsubk, # Public-Subkey Packet
    17 => :uattr, # User Attribute Packet
    18 => :seipdata, # Sym. Encrypted and Integrity Protected Data Packet
    19 => :moddetcode, # Modification Detection Code Packet
  }

  @signature_types %{
    0x00 => :binary_doc, # Signature of a binary document
    0x01 => :text_doc, # Signature of a canonical text document
    0x02 => :standalone, # Standalone signature
    0x10 => :generic_cert, # Generic certification of a User ID and Public-Key packet
    0x11 => :persona_cert, # Persona certification of a User ID and Public-Key packet
    0x12 => :casual_cert, # Casual certification of a User ID and Public-Key packet
    0x13 => :positive_cert, # Positive certification of a User ID and Public-Key packet
    0x18 => :sub_key, # Subkey Binding Signature
    0x19 => :primary_key, # Primary Key Binding Signature
    0x1f => :key, # Signature directly on a key
    0x20 => :key_revocation, # Key revocation signature
    0x28 => :sub_key_revocation, # Subkey revocation signature
    0x30 => :cert_revocation, # Certification revocation signature
    0x40 => :timestamp, # Timestamp signature
    0x50 => :third_party_confirmation # Third-Party Confirmation signature
  }

  @signature_sub_types %{
    0 => :reserved, # Reserved
    1 => :reserved, # Reserved
    2 => :creation_time, # Signature Creation Time
    3 => :expiration_time, # Signature Expiration Time
    4 => :export_cert, #Exportable Certification
    5 => :trust, # Trust Signature
    6 => :regular_expr, #Regular Expression
    7 => :revocable, # Revocable
    8 => :reserved, #Reserved
    9 => :key_expiration_time, # Key Expiration Time
    10 => :reserved, # Placeholder for backward compatibility
    11 => :preferred_sym_algo, # Preferred Symmetric Algorithms
    12 => :revocation_key, # Revocation Key
    13 => :reserved, # Reserved
    14 => :reserved, # Reserved
    15 => :reserved, # Reserved
    16 => :issuer, # Issuer
    17 => :reserved, # Reserved
    18 => :reserved, # Reserved
    19 => :reserved, # Reserved
    20 => :nodation, # Notation Data
    21 => :preferred_hash_algo, # Preferred Hash Algorithms
    22 => :preferred_comp_algo, # Preferred Compression Algorithms
    23 => :key_server_prefs, # Key Server Preferences
    24 => :preferred_key_server, # Preferred Key Server
    25 => :primary_uid, # Primary User ID
    26 => :policy_uri, # Policy URI
    27 => :key_flags, # Key Flags
    28 => :sign_uid, # Signer's User ID
    29 => :revocation_reason, # Reason for Revocation
    30 => :features, # Features
    31 => :target, # Signature Target
    32 => :embedded, # Embedded Signature
  }

  @pub_key_algos %{
    1 => :rsa, # RSA (Encrypt or Sign)
    2 => :rsa, # RSA Encrypt-Only
    3 => :rsa, # RSA Sign-Only
    16 => :elgamal, # Elgamal (Encrypt-Only)
    17 => :dsa, # DSA (Digital Signature Algorithm)
    18 => :reserved, # Reserved for Elliptic Curve
    19 => :reserved, # Reserved for ECDSA
    20 => :reserved, # Reserved (formerly Elgamal Encrypt or Sign)
    21 => :reserved, # Reserved for Diffie-Hellman (X9.42, as defined for IETF-S/MIME)
  }

  @sym_key_algos %{
    0 => :plain, # Plaintext or unencrypted data
    1 => :idea, # IDEA
    2 => :triple_des, # TripleDES (168 bit key derived from 192)
    3 => :cast5, # CAST5 (128 bit key, as per RFC2144)
    4 => :blowfish, # Blowfish (128 bit key, 16 rounds)
    5 => :reserved, # Reserved
    6 => :reserved, # Reserved
    7 => :aes128, # AES with 128-bit key
    8 => :aes192, # AES with 192-bit key
    9 => :aes256, # AES with 256-bit key
    10 => :twofish, # Twofish with 256-bit key
  }

  @comp_algos %{
    0 => :uncompressed, # Uncompressed
    1 => :zip, # ZIP
    2 => :zlib, # ZLIB
    3 => :bzip2, # BZip2
  }

  @hash_algos %{
    1 => :md5,
    2 => :sha1,
    3 => :ripemd160,
    4 => :reserved,
    5 => :reserved,
    6 => :reserved,
    7 => :reserved,
    8 => :sha256,
    9 => :sha384,
    10 => :sha512,
    11 => :sha224,
  }

  @doc """
  Creates a new SSH key with the given `params`.

  ```elixir
  {:ok, gpg_key} = GitGud.GPGKey.create(user_id: user.id, data: "...")
  ```

  This function validates the given `params` using `changeset/2`.
  """
  @spec create(map|keyword) :: {:ok, t} | {:error, Ecto.Changeset.t}
  def create(params) do
    DB.insert(changeset(%__MODULE__{}, Map.new(params)))
  end

  @doc """
  Similar to `create/1`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec create!(map|keyword) :: t
  def create!(params) do
    DB.insert!(changeset(%__MODULE__{}, Map.new(params)))
  end

  @doc """
  Deletes the given `gpg_key`.
  """
  @spec delete(t) :: {:ok, t} | {:error, Ecto.Changeset.t}
  def delete(%__MODULE__{} = gpg_key) do
    DB.delete(gpg_key)
  end

  @doc """
  Similar to `delete!/1`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec delete!(t) :: t
  def delete!(%__MODULE__{} = gpg_key) do
    DB.delete!(gpg_key)
  end

  @doc """
  Returns a GPG key changeset for the given `params`.
  """
  @spec changeset(t, map) :: Ecto.Changeset.t
  def changeset(%__MODULE__{} = gpg_key, params \\ %{}) do
    gpg_key
    |> cast(params, [:user_id, :data])
    |> validate_required([:user_id, :data])
    |> put_data()
    |> unique_constraint(:key_id, name: :gpg_keys_user_id_key_id_index)
    |> assoc_constraint(:user)
  end

  @doc """
  Decodes the given *ASCII armor* `message`.
  """
  @spec decode!(binary) :: binary
  def decode!(message) do
    {_checksum, lines} =
      message
      |> String.trim()
      |> String.split(["\n", "\r", "\r\n"])
      |> List.delete_at(0)
      |> List.delete_at(-1)
      |> IO.inspect
      |> Enum.drop_while(&(&1 != ""))
      |> List.delete_at(0)
      |> List.pop_at(-1)
    lines
    |> Enum.join()
    |> Base.decode64!()
  end

  def parse!(data) do
    parse_packet(data, [])
  end

  #
  # Helpers
  #

  defp put_data(changeset) do
    if armored_data = changeset.valid? && get_change(changeset, :data) do
      data = decode!(armored_data)
      gpg_key = parse!(data)
      pub_key = Keyword.fetch!(gpg_key, :pubk)
      pub_sig = Keyword.fetch!(gpg_key, :sig)
      changeset
      |> put_change(:key_id, pub_key.fingerprint)
      |> put_change(:sub_keys, Enum.map(Keyword.get_values(gpg_key, :pubsubk), &(&1.fingerprint)))
      |> put_change(:emails, Enum.map(Keyword.get_values(gpg_key, :uid), &(&1.email)))
      |> put_change(:expires_at, DateTime.to_naive(DateTime.add(pub_key.timestamp, Keyword.get(pub_sig.sub_pack, :key_expiration_time, 0))))
    end || changeset
  end

  defp parse_packet("", acc), do: Enum.reverse(acc)
  defp parse_packet(data, acc) do
    {tag, data, rest} = parse_packet_header(data)
    parse_packet(rest, [{tag, parse_packet_tag(tag, data)}|acc])
  end

  defp parse_packet_header(<<1::1, 0::1, t::4, 0::2, len::8, data::binary-size(len), rest::binary>>), do: {@packet_types[t], data, rest}
  defp parse_packet_header(<<1::1, 0::1, t::4, 1::2, len::16, data::binary-size(len), rest::binary>>), do: {@packet_types[t], data, rest}
  defp parse_packet_header(<<1::1, 0::1, t::4, 2::2, len::32, data::binary-size(len), rest::binary>>), do: {@packet_types[t], data, rest}
  defp parse_packet_header(<<1::1, 1::1, t::6, 255, len::32, data::binary-size(len), rest::binary>>), do: {@packet_types[t], data, rest}
  defp parse_packet_header(<<1::1, 1::1, t::6, len::8, data::binary-size(len), rest::binary>>) when len < 192, do: {@packet_types[t], data, rest}
  defp parse_packet_header(<<1::1, 1::1, t::6, len::8, len2::8, rest::binary>>) when len < 224 do
    len = len + len2
    <<data::binary-size(len), rest::binary>> = rest
    {@packet_types[t], data, rest}
  end

  defp parse_packet_header(_header), do: :error

  defp parse_packet_tag(:pkesk, <<version::8, key_id::binary-size(8), hash_algo::8, data::binary>>) do
    %{version: version, key_id: key_id, hash_algo: hash_algo, session_key: data}
  end

  defp parse_packet_tag(:sig, <<3, t::8, timestamp::32, key_id::binary-size(8), pub_algo::8, prefix::binary-size(2), sig::binary>>) do
    %{version: 3, type: @signature_types[t], timestamp: DateTime.from_unix!(timestamp), key_id: key_id, pub_algo: @pub_key_algos[pub_algo], prefix: prefix, signature: sig}
  end

  defp parse_packet_tag(:sig, <<4, t::8, pub_algo::8, hash_algo::8, hashed_sub_size::16, hashed_sub::binary-size(hashed_sub_size), unhashed_sub_size::16, unhashed_sub::binary-size(unhashed_sub_size), prefix::binary-size(2), sig::binary>>) do
    %{version: 4, type: @signature_types[t], pub_algo: @pub_key_algos[pub_algo], hash_algo: @hash_algos[hash_algo], sub_pack: parse_packet_sig_sub(hashed_sub, []) ++ parse_packet_sig_sub(unhashed_sub, []), prefix: prefix, signature: sig}
  end

  defp parse_packet_tag(tag, <<4, timestamp::32, pub_algo::8, data::binary>> = tag_data) when tag in [:pubk, :pubsubk] do
    tag_size = byte_size(tag_data)
    %{version: 4, timestamp: DateTime.from_unix!(timestamp), pub_algo: @pub_key_algos[pub_algo], fingerprint: :crypto.hash(:sha, <<0x99, tag_size::16>> <> tag_data), data: data}
  end

  defp parse_packet_tag(:uid, uid) do
    ~r/^(?<name>.+) <(?<email>.+)>/
    |> Regex.named_captures(uid)
    |> Map.new(fn {key, val} -> {String.to_atom(key), val} end)
  end

  defp parse_packet_tag(_tag, data), do: data

  defp parse_packet_sig_sub("", acc), do: Enum.reverse(acc)
  defp parse_packet_sig_sub(<<255, len::32, data::binary-size(len), rest::binary>>, acc) do
    <<t::8, data::binary>> = data
    parse_packet_sig_sub(rest, [parse_packet_sig_sub_data(@signature_sub_types[t], data)|acc])
  end

  defp parse_packet_sig_sub(<<len::8, data::binary-size(len), rest::binary>>, acc) when len < 192 do
    <<t::8, data::binary>> = data
    parse_packet_sig_sub(rest, [parse_packet_sig_sub_data(@signature_sub_types[t], data)|acc])
  end

  defp parse_packet_sig_sub(<<len::8, len2::8, rest::binary>>, acc) when len < 224 do
    len = len + len2
    <<t::8, data::binary-size(len), rest::binary>> = rest
    parse_packet_sig_sub(rest, [parse_packet_sig_sub_data(@signature_sub_types[t], data)|acc])
  end

  defp parse_packet_sig_sub_data(:creation_time = type, timestamp), do: {type, DateTime.from_unix!(:binary.decode_unsigned(timestamp))}
  defp parse_packet_sig_sub_data(type, timestamp) when type in [:expiration_time, :key_expiration_time], do: {type, :binary.decode_unsigned(timestamp)}
  defp parse_packet_sig_sub_data(:preferred_sym_algo = type, data), do: {type || :undefined, Enum.map(:binary.bin_to_list(data), &Map.get(@sym_key_algos, &1, :undefined))}
  defp parse_packet_sig_sub_data(:preferred_hash_algo = type, data), do: {type || :undefined, Enum.map(:binary.bin_to_list(data), &Map.get(@hash_algos, &1, :undefined))}
  defp parse_packet_sig_sub_data(:preferred_comp_algo = type, data), do: {type || :undefined, Enum.map(:binary.bin_to_list(data), &Map.get(@comp_algos, &1, :undefined))}
  defp parse_packet_sig_sub_data(type, data), do: {type || :undefined, data}
end
