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
    assert {:error, changeset} = User.create(Map.delete(params, :email))
    assert "can't be blank" in errors_on(changeset).email
  end

  test "fails to create a new user with invalid password" do
    params = factory(:user)
    assert {:error, changeset} = User.create(Map.delete(params, :password))
    assert "can't be blank" in errors_on(changeset).password
    assert {:error, changeset} = User.create(%{params|password: "abc"})
    assert "should be at least 6 character(s)" in errors_on(changeset).password
  end

  describe "when user exists" do
    setup [:create_user]

    test "updates profile with valid params", %{user: user} do
      assert {:ok, user} = User.update(user, :profile, name: "Alice", email: "alice1234@gmail.com")
      assert user.name == "Alice"
      assert user.email == "alice1234@gmail.com"
    end

    test "fails to update profile with invalid email", %{user: user} do
      assert {:error, changeset} = User.update(user, :profile, email: "")
      assert "can't be blank" in errors_on(changeset).email
    end

    test "deletes user", %{user: user} do
      assert {:ok, _user} = User.delete(user)
    end

    test "checks credentials", %{user: user} do
      assert ^user = User.check_credentials(user.username, "qwertz")
      assert ^user = User.check_credentials(user.email, "qwertz")
    end

    test "fails to check credentials with invalid password", %{user: user} do
      assert is_nil(User.check_credentials(user.email, "abc"))
      assert is_nil(User.check_credentials(user.username, "abc"))
    end
  end

  #
  # Helpers
  #

  defp create_user(context) do
    Map.put(context, :user, User.create!(factory(:user)))
  end
end
