defmodule GitGud.UserTest do
  use GitGud.DataCase, async: true
  use GitGud.DataFactory

  alias GitGud.Account
  alias GitGud.User
  alias GitGud.Email

  test "creates a new user with valid params" do
    assert {:ok, user} = User.create(factory(:user))
    assert is_nil(user.account.password)
    assert String.starts_with?(user.account.password_hash, "$argon2id$")
  end

  test "fails to create a new user with invalid login" do
    params = factory(:user)
    assert {:error, changeset} = User.create(Map.delete(params, :login))
    assert "can't be blank" in errors_on(changeset).login
    assert {:error, changeset} = User.create(Map.update!(params, :login, &(&1<>".")))
    assert "has invalid format" in errors_on(changeset).login
    assert {:error, changeset} = User.create(Map.update!(params, :login, &binary_part(&1, 0, 2)))
    assert "should be at least 3 character(s)" in errors_on(changeset).login
  end

  test "fails to create a new user with invalid email" do
    params = factory(:user)
    assert {:error, changeset} = User.create(Map.delete(params, :emails))
    assert "can't be blank" in errors_on(changeset).emails
    assert {:error, changeset} = User.create(Map.update!(params, :emails, fn emails -> List.update_at(emails, 0, &%{&1|address: &1.address <> ".$"}) end))
    assert %{address: ["has invalid format"]} in errors_on(changeset).emails
  end

  test "fails to create a new user with invalid password" do
    params = factory(:user)
    assert {:error, changeset} = User.create(%{params|account: %{}})
    assert "can't be blank" in errors_on(changeset).account.password
    assert {:error, changeset} = User.create(%{params|account: %{password: "abc"}})
    assert "should be at least 6 character(s)" in errors_on(changeset).account.password
  end

  describe "when user exists" do
    setup :create_user

    test "checks credentials", %{user: user} do
      assert Account.check_credentials(user.login, "qwertz")
      assert Account.check_credentials(hd(user.emails).address, "qwertz")
    end

    test "fails to check credentials with invalid password", %{user: user} do
      refute Account.check_credentials(user.login, "abc")
      refute Account.check_credentials(hd(user.emails).address, "abc")
    end

    test "fails to create a new user with already existing login", %{user: user} do
      params = factory(:user)
      assert {:error, changeset} = User.create(%{params|login: user.login})
      assert "has already been taken" in errors_on(changeset).login
    end

    test "updates profile with valid params", %{user: user1} do
      assert {:ok, user2} = User.update(user1, :profile, name: "Alice", bio: "I love programming!", public_email_id: hd(user1.emails).id, website_url: "http://www.example.com")
      assert user2.name == "Alice"
      assert user2.bio == "I love programming!"
      assert user2.public_email_id == hd(user1.emails).id
      assert user2.website_url == "http://www.example.com"
    end

    test "fails to update profile with invalid public email", %{user: user} do
      assert {:error, changeset} = User.update(user, :profile, public_email_id: 0)
      assert "does not exist" in errors_on(changeset).public_email
    end

    test "fails to update profile with invalid website url", %{user: user} do
      assert {:error, changeset} = User.update(user, :profile, website_url: "http:example.com")
      assert "invalid" in errors_on(changeset).website_url
    end

    test "updates password with valid params", %{user: user1} do
      assert {:ok, user2} = User.update(user1, :password, old_password: "qwertz", password: "qwerty")
      assert user1.account.password_hash != user2.account.password_hash
    end

    test "fails to update password with invalid old password", %{user: user} do
      assert {:error, changeset} = User.update(user, :password, old_password: "abcdef", password: "qwerty")
      assert "does not match old password" in errors_on(changeset).account.old_password
    end

    test "fails to update password with invalid new password", %{user: user} do
      assert {:error, changeset} = User.update(user, :password, old_password: "qwertz")
      assert "can't be blank" in errors_on(changeset).account.password
      assert {:error, changeset} = User.update(user, :password, old_password: "qwertz", password: "abc")
      assert "should be at least 6 character(s)" in errors_on(changeset).account.password
    end

    test "updates primary email with valid email", %{user: user1} do
      assert {:ok, user2} = User.update(user1, :primary_email, hd(user1.emails))
      assert user2.primary_email == hd(user1.emails)
    end

    test "updates public email with valid email", %{user: user1} do
      assert {:ok, user2} = User.update(user1, :public_email, hd(user1.emails))
      assert user2.public_email == hd(user1.emails)
    end

    test "deletes user", %{user: user1} do
      assert {:ok, user2} = User.delete(user1)
      assert user2.__meta__.state == :deleted
    end
  end

  #
  # Helpers
  #

  defp create_user(context) do
    user = User.create!(factory(:user))
    Map.put(context, :user, struct(user, emails: Enum.map(user.emails, &Email.verify!/1)))
  end
end
