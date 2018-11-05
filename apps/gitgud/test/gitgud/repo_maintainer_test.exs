defmodule GitGud.RepoMaintainerTest do
  use GitGud.DataCase, async: true
  use GitGud.DataFactory

  alias GitGud.User
  alias GitGud.Repo
  alias GitGud.RepoMaintainer

  setup [:create_users, :create_repo]

  test "creates a new maintainer with valid params", %{users: [_user1, user2], repo: repo} do
    assert {:ok, maintainer} = RepoMaintainer.create(user_id: user2.id, repo_id: repo.id)
    assert maintainer.permission == "read"
  end

  test "fails to create a new maintainer with invalid permission", %{users: [_user1, user2], repo: repo} do
    assert {:error, changeset} = RepoMaintainer.create(user_id: user2.id, repo_id: repo.id, permission: "foobar")
    assert "is invalid" in errors_on(changeset).permission
  end

  describe "when maintainer exists" do
    setup :create_maintainer

    test "updates maintainer permission with valid permission", %{maintainer: maintainer1} do
      assert {:ok, maintainer2} = RepoMaintainer.update_permission(maintainer1, "write")
      assert maintainer2.permission == "write"
    end

    test "fails to update maintainer permission with invalid permission", %{maintainer: maintainer} do
      assert {:error, changeset} = RepoMaintainer.update_permission(maintainer, "foobar")
      assert "is invalid" in errors_on(changeset).permission
    end

    test "deletes maintainer", %{maintainer: maintainer1} do
      assert {:ok, maintainer2} = RepoMaintainer.delete(maintainer1)
      assert maintainer2.__meta__.state == :deleted
    end
  end

  #
  # Helpers
  #

  defp create_users(context) do
    users = Stream.repeatedly(fn -> User.create!(factory(:user)) end)
    Map.put(context, :users, Enum.take(users, 2))
  end

  defp create_repo(context) do
    {repo, _git_handle} = Repo.create!(factory(:repo, hd(context.users)))
    Map.put(context, :repo, repo)
  end

  defp create_maintainer(context) do
    maintainer = RepoMaintainer.create!(user_id: List.last(context.users).id, repo_id: context.repo.id)
    context
    |> Map.put(:maintainer, maintainer)
    |> Map.update!(:repo, &DB.preload(&1, :maintainers))
  end
end
