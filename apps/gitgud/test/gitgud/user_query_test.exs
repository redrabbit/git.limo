defmodule GitGud.UserQueryTest do
  use GitGud.DataCase, async: true
  use GitGud.DataFactory

  alias GitGud.User
  alias GitGud.UserQuery

  setup :create_users

  test "gets single user by id", %{users: users} do
    for user <- users do
      assert ^user = UserQuery.by_id(user.id)
    end
  end

  test "gets multiple users by id", %{users: users} do
    assert ^users = UserQuery.by_id(Enum.map(users, &(&1.id)))
  end

  test "gets single user by username", %{users: users} do
    for user <- users do
      assert ^user = UserQuery.by_username(user.username)
    end
  end

  test "gets multiple users by username", %{users: users} do
    assert ^users = UserQuery.by_username(Enum.map(users, &(&1.username)))
  end

  test "gets single user by email", %{users: users} do
    for user <- users do
      assert ^user = UserQuery.by_email(user.email)
    end
  end

  test "gets multiple users by email", %{users: users} do
    assert ^users = UserQuery.by_email(Enum.map(users, &(&1.email)))
  end

  #
  # Helpers
  #

  defp create_users(context) do
    users = Stream.repeatedly(fn -> User.create!(factory(:user)) end)
    Map.put(context, :users, Enum.take(users, 10))
  end
end

