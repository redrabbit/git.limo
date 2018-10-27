defmodule GitGud.UserQueryTest do
  use GitGud.DataCase, async: true
  use GitGud.DataFactory

  alias GitGud.User
  alias GitGud.UserQuery

  setup :create_users

  test "gets single user by id", %{users: users} do
    for user <- users do
      assert user == UserQuery.by_id(user.id, preload: [:primary_email, :emails])
    end
  end

  test "gets multiple users by id", %{users: users} do
    assert Enum.all?(UserQuery.by_id(Enum.map(users, &(&1.id)), preload: [:primary_email, :emails]), &(&1 in users))
  end

  test "gets single user by username", %{users: users} do
    for user <- users do
      assert user == UserQuery.by_username(user.username, preload: [:primary_email, :emails])
    end
  end

  test "gets multiple users by username", %{users: users} do
    assert Enum.all?(UserQuery.by_username(Enum.map(users, &(&1.username)), preload: [:primary_email, :emails]), &(&1 in users))
  end

  test "gets single user by email", %{users: users} do
    for user <- users do
      assert user == UserQuery.by_email(user.primary_email.email, preload: [:primary_email, :emails])
    end
  end

  test "gets multiple users by email", %{users: users} do
    assert Enum.all?(UserQuery.by_email(Enum.map(users, &(&1.primary_email.email)), preload: [:primary_email, :emails]), &(&1 in users))
  end

  #
  # Helpers
  #

  defp create_users(context) do
    users =
      Stream.repeatedly(fn ->
        user = User.create!(factory(:user))
        user
        |> struct(emails: Enum.map(user.emails, &GitGud.Email.update!(&1, verified: true)))
        |> struct(primary_email: struct(user.primary_email, verified: true))
      end)
    Map.put(context, :users, Enum.take(users, 3))
  end
end
