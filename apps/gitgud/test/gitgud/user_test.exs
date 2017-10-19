defmodule GitGud.UserTest do
  use GitGud.DataCase

  alias GitGud.User
  alias GitGud.UserQuerySet

  @valid_attrs %{name: "Mario Flach", username: "redrabbit", email: "m.flach@almightycouch.com", password: "test1234"}

  test "registers a new user with valid params" do
    assert {:ok, user} = User.register(@valid_attrs)
    assert is_nil(user.password)
    assert String.starts_with?(user.password_hash, "$argon2i$")
  end

  test "fails to register a new user with invalid params" do
    assert {:error, changeset} = User.register(%{@valid_attrs|username: "mariö"})
    assert "has invalid format" in errors_on(changeset).username
    assert {:error, changeset} = User.register(%{@valid_attrs|username: "rr"})
    assert "should be at least 3 character(s)" in errors_on(changeset).username
    assert {:error, changeset} = User.register(%{@valid_attrs|email: "m-dot-flach-at-almightycouch-dot-com"})
    assert "has invalid format" in errors_on(changeset).email
    assert {:error, changeset} = User.register(%{@valid_attrs|password: "test1"})
    assert "should be at least 6 character(s)" in errors_on(changeset).password
  end

  test "gets user by id" do
    assert {:ok, user} = User.register(@valid_attrs)
    assert ^user = UserQuerySet.get(user.id)
  end

  test "gets user by username" do
    assert {:ok, user} = User.register(@valid_attrs)
    assert ^user = UserQuerySet.get(user.username)
  end

  test "authenticates user with email and username" do
    assert {:ok, user} = User.register(@valid_attrs)
    assert ^user = User.check_credentials(@valid_attrs.email, @valid_attrs.password)
    assert ^user = User.check_credentials(@valid_attrs.username, @valid_attrs.password)
  end

  test "fails to authenticate user with invalid credentials" do
    assert {:ok, user} = User.register(@valid_attrs)
    assert is_nil(User.check_credentials(user.email, "testpasswd"))
    assert is_nil(User.check_credentials(user.username, "testpasswd"))
  end
end
