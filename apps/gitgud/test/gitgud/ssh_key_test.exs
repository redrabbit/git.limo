defmodule GitGud.SSHKeyTest do
  use GitGud.DataCase, async: true
  use GitGud.DataFactory

  alias GitGud.User
  alias GitGud.SSHKey

  setup :create_user

  test "creates a new ssh authentication key with valid params", %{user: user} do
    assert {:ok, ssh_key} = SSHKey.create(factory(:ssh_key, user))
    assert [{key, _attrs}] = :public_key.ssh_decode(ssh_key.data, :public_key)
    assert ssh_key.fingerprint == to_string(:public_key.ssh_hostkey_fingerprint(key))
  end

  test "fails to create a new ssh authentication key with invalid public key", %{user: user} do
    params = factory(:ssh_key, user)
    assert {:error, changeset} = SSHKey.create(Map.delete(params, :data))
    assert "can't be blank" in errors_on(changeset).data
    assert {:error, changeset} = SSHKey.create(Map.update!(params, :data, &binary_part(&1, 0, 12)))
    assert "invalid" in errors_on(changeset).data
  end

  describe "when ssh authentication key exists" do
    setup :create_ssh_key

    test "deletes key", %{ssh_key: ssh_key1} do
      assert {:ok, ssh_key2} = SSHKey.delete(ssh_key1)
      assert ssh_key2.__meta__.state == :deleted
    end
  end

  #
  # Helpers
  #

  defp create_user(context) do
    Map.put(context, :user, User.create!(factory(:user)))
  end

  defp create_ssh_key(context) do
    Map.put(context, :ssh_key, SSHKey.create!(factory(:ssh_key, context.user)))
  end
end
