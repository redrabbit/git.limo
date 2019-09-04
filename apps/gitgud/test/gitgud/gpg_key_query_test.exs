defmodule GitGud.GPGKeyQueryTest do
  use GitGud.DataCase, async: true
  use GitGud.DataFactory

  alias GitGud.User
  alias GitGud.GPGKey
  alias GitGud.GPGKeyQuery

  setup [:create_users, :create_gpg_keys]

  test "gets single gpg key by id", %{gpg_keys: gpg_keys} do
    for gpg_key <- gpg_keys do
      assert gpg_key.id == GPGKeyQuery.by_id(gpg_key.id).id
    end
  end

  test "gets single gpg key by key id", %{gpg_keys: gpg_keys} do
    for gpg_key <- gpg_keys do
      assert gpg_key.id == GPGKeyQuery.by_key_id(gpg_key.key_id).id
    end
  end

  test "gets multiple gpg keys by key id", %{gpg_keys: gpg_keys} do
    results = GPGKeyQuery.by_key_id(Enum.map(gpg_keys, &(&1.key_id)))
    assert Enum.count(results) == length(gpg_keys)
    assert Enum.all?(results, &(&1.id in Enum.map(gpg_keys, fn gpg_key -> gpg_key.id end)))
  end

  #
  # Helpers
  #

  defp create_users(context) do
    users = Enum.take(Stream.repeatedly(fn -> User.create!(factory(:user)) end), 2)
    Map.put(context, :users, users)
  end

  defp create_gpg_keys(context) do
    gpg_keys = Enum.flat_map(context.users, &Enum.take(Stream.repeatedly(fn -> GPGKey.create!(factory(:gpg_key, &1)) end), 3))
    Map.put(context, :gpg_keys, gpg_keys)
  end
end
