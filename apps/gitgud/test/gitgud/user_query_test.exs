defmodule GitGud.UserQueryTest do
  use GitGud.DataCase, async: true
  use GitGud.DataFactory

  alias GitGud.User
  alias GitGud.UserQuery

  setup :create_users

  test "gets single user by id", %{users: users} do
    for user <- users do
      assert user == UserQuery.by_id(user.id, preload: :emails)
    end
  end

  test "gets multiple users by id", %{users: users} do
    assert Enum.all?(UserQuery.by_id(Enum.map(users, &(&1.id)), preload: :emails), &(&1 in users))
  end

  test "gets single user by username", %{users: users} do
    for user <- users do
      assert user == UserQuery.by_username(user.username, preload: :emails)
    end
  end

  test "gets multiple users by username", %{users: users} do
    assert Enum.all?(UserQuery.by_username(Enum.map(users, &(&1.username)), preload: :emails), &(&1 in users))
  end

  test "gets single user by email", %{users: users} do
    for user <- users do
      assert user == UserQuery.by_email(hd(user.emails).email, preload: :emails)
    end
  end

  test "gets multiple users by email", %{users: users} do
    assert Enum.all?(UserQuery.by_email(Enum.map(users, &hd(&1.emails).email), preload: :emails), &(&1 in users))
  end

  #
  # Helpers
  #

  defp create_users(context) do
    users =
      Stream.repeatedly(fn ->
        user = User.create!(factory(:user))
        struct(user, emails: Enum.map(user.emails, &GitGud.Email.update!(&1, verified: true)))
      end)
    Map.put(context, :users, Enum.take(users, 3))
  end
end
