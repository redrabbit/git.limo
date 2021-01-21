defmodule GitGud.GPGKeyQuery do
  @moduledoc """
  Conveniences for GPG key related queries.
  """

  @behaviour GitGud.DBQueryable

  alias GitGud.DB
  alias GitGud.DBQueryable

  alias GitGud.GPGKey

  import Ecto.Query

  @doc """
  Returns a GPG key for the given `id`.
  """
  @spec by_id(pos_integer, keyword) :: GPGKey.t | nil
  def by_id(id, opts \\ []) do
    DB.one(DBQueryable.query({__MODULE__, :gpg_key_query}, [id], opts))
  end

  @doc """
  Returns a GPG key for the given `key_id`.

  Note that this function support 32 bit and 64 bit key ids.
  """
  @spec by_key_id(binary, keyword) :: GPGKey.t | nil
  @spec by_key_id([binary], keyword) :: [GPGKey.t]
  def by_key_id(key_id, opts \\ [])
  def by_key_id(key_ids, opts) when is_list(key_ids) do
    DB.all(DBQueryable.query({__MODULE__, :gpg_keys_query}, [key_ids], opts))
  end

  def by_key_id(key_id, opts) do
    DB.one(DBQueryable.query({__MODULE__, :gpg_key_query}, [key_id], opts))
  end

  #
  # Callbacks
  #

  @impl true
  def query(:gpg_key_query, [id]) when is_integer(id) do
    from(g in GPGKey, as: :gpg_key, where: g.id == ^id)
  end

  def query(:gpg_key_query, [key_id]) when is_binary(key_id) and byte_size(key_id) == 20 do
    from(g in GPGKey, as: :gpg_key, where: g.key_id == ^key_id)
  end

  def query(:gpg_key_query, [key_id]) when is_binary(key_id) and byte_size(key_id) == 8 do
    from(g in GPGKey, as: :gpg_key, where: fragment("substring(?, 13, 8)", g.key_id) == ^key_id)
  end

  def query(:gpg_keys_query, [key_ids]) when is_list(key_ids) do
    cond do
      Enum.all?(key_ids, &(byte_size(&1) == 20)) ->
        from(g in GPGKey, as: :gpg_key, where: g.key_id in ^key_ids)
      Enum.all?(key_ids, &(byte_size(&1) == 8)) ->
        from(g in GPGKey, as: :gpg_key, where: fragment("substring(?, 13, 8)", g.key_id) in ^key_ids)
    end
  end

  @impl true
  def alter_query(query, [], _viewer), do: query

  def alter_query(query, [preload|tail], viewer) do
    query
    |> join_preload(preload, viewer)
    |> alter_query(tail, viewer)
  end

  #
  # Helpers
  #

  defp join_preload(query, :user, _viewer) do
    query
    |> join(:left, [gpg_key: g], u in assoc(g, :user), as: :user)
    |> preload([user: u], [user: u])
  end

  defp join_preload(query, preload, _viewer) do
    preload(query, ^preload)
  end
end
