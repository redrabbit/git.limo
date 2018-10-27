defmodule GitGud.UserTest do
  use GitGud.DataCase, async: true
  use GitGud.DataFactory

  alias GitGud.User

  test "creates a new user with valid params" do
    assert {:ok, user} = User.create(factory(:user))
    assert is_nil(user.password)
    assert String.starts_with?(user.password_hash, "$argon2i$")
  end

  test "fails to create a new user with invalid username" do
    params = factory(:user)
    assert {:error, changeset} = User.create(Map.delete(params, :username))
    assert "can't be blank" in errors_on(changeset).username
    assert {:error, changeset} = User.create(Map.update!(params, :username, &(&1<>".")))
    assert "has invalid format" in errors_on(changeset).username
    assert {:error, changeset} = User.create(Map.update!(params, :username, &binary_part(&1, 0, 2)))
    assert "should be at least 3 character(s)" in errors_on(changeset).username
  end

  test "fails to create a new user with invalid email" do
    params = factory(:user)
    assert {:error, changeset} = User.create(Map.delete(params, :emails))
    assert "can't be blank" in errors_on(changeset).emails
    assert {:error, changeset} = User.create(Map.update!(params, :emails, fn emails -> List.update_at(emails, 0, &%{&1|email: &1.email <> ".0"}) end))
    assert %{email: ["has invalid format"]} in errors_on(changeset).emails
  end

  test "fails to create a new user with weak password" do
    params = factory(:user)
    assert {:error, changeset} = User.create(Map.delete(params, :password))
    assert "can't be blank" in errors_on(changeset).password
    assert {:error, changeset} = User.create(%{params|password: "abc"})
    assert "should be at least 6 character(s)" in errors_on(changeset).password
  end

  describe "when user exists" do
    setup [:create_user]

    test "fails to create a new user with same username", %{user: user} do
      params = factory(:user)
      assert {:error, changeset} = User.create(%{params|username: user.username})
      assert "has already been taken" in errors_on(changeset).username
    end

    test "updates profile with valid params", %{user: user1} do
      assert {:ok, user2} = User.update(user1, :profile, name: "Alice")
      assert user2.name == "Alice"
    end

    test "deletes user", %{user: user1} do
      assert {:ok, user2} = User.delete(user1)
      assert user2.__meta__.state == :deleted
    end

    test "checks credentials", %{user: user} do
      assert User.check_credentials(user.username, "qwertz")
      assert User.check_credentials(user.primary_email.email, "qwertz")
    end

    test "fails to check credentials with weak password", %{user: user} do
      refute User.check_credentials(user.username, "abc")
      refute User.check_credentials(user.primary_email.email, "abc")
    end
  end

  #
  # Helpers
  #

  defp create_user(context) do
    user = User.create!(factory(:user))
    Map.put(context, :user, struct(user, emails: Enum.map(user.emails, &GitGud.Email.update!(&1, verified: true))))
  end
end
