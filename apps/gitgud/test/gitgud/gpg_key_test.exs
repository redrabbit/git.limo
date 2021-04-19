defmodule GitGud.GPGKeyTest do
  use GitGud.DataCase, async: true
  use GitGud.DataFactory

  alias GitGud.User
  alias GitGud.GPGKey

  setup :create_user

  @tag :skip
  test "creates a new gpg key with valid params", %{user: user} do
    assert {:ok, gpg_key} = GPGKey.create(user, factory(:gpg_key, user))
    assert byte_size(gpg_key.key_id) == 20
    assert Enum.all?(user.emails, &(&1.address in gpg_key.emails))
  end

  @tag :skip
  test "fails to create a new gpg key with invalid public key", %{user: user} do
    params = factory(:gpg_key, user)
    assert {:error, changeset} = GPGKey.create(user, Map.delete(params, :data))
    assert "can't be blank" in errors_on(changeset).data
    assert {:error, changeset} = GPGKey.create(user, Map.put(params, :data, "-----BEGIN PGP PUBLIC KEY BLOCK-----\n-----END PGP PUBLIC KEY BLOCK-----\n"))
    assert "invalid" in errors_on(changeset).data
  end

  describe "when gpg key exists" do
    setup :create_gpg_key

    @tag :skip
    test "deletes key", %{gpg_key: gpg_key1} do
      assert {:ok, gpg_key2} = GPGKey.delete(gpg_key1)
      assert gpg_key2.__meta__.state == :deleted
    end
  end

#
# Helpers
#

  defp create_user(context) do
    Map.put(context, :user, User.create!(factory(:user)))
  end

  defp create_gpg_key(context) do
    Map.put(context, :gpg_key, GPGKey.create!(context.user, factory(:gpg_key, context.user)))
  end
end
