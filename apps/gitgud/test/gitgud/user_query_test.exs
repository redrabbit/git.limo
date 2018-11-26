defmodule GitGud.UserQueryTest do
  use GitGud.DataCase, async: true
  use GitGud.DataFactory

  alias GitGud.Email
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

  test "gets single user by login", %{users: users} do
    for user <- users do
      assert user == UserQuery.by_login(user.login, preload: :emails)
    end
  end

  test "gets multiple users by login", %{users: users} do
    assert Enum.all?(UserQuery.by_login(Enum.map(users, &(&1.login)), preload: :emails), &(&1 in users))
  end

  test "gets single user by email", %{users: users} do
    for user <- users do
      assert user == UserQuery.by_email(hd(user.emails).address, preload: :emails)
    end
  end

  test "gets multiple users by email", %{users: users} do
    assert Enum.all?(UserQuery.by_email(Enum.map(users, &(hd(&1.emails).address)), preload: :emails), &(&1 in users))
  end

  #
  # Helpers
  #

  defp create_users(context) do
    users =
      Stream.repeatedly(fn ->
        user = User.create!(factory(:user))
        struct(user, emails: Enum.map(user.emails, &Email.verify!/1), primary_email_id: hd(user.emails).id)
      end)
    Map.put(context, :users, Enum.take(users, 3))
  end
end
