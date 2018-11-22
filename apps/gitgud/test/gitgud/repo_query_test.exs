defmodule GitGud.RepoQueryTest do
  use GitGud.DataCase, async: true
  use GitGud.DataFactory

  alias GitGud.User
  alias GitGud.Repo
  alias GitGud.RepoQuery

  setup [:create_users, :create_repos]

  test "gets single repository by id", %{repos: repos} do
    for repo <- repos do
      assert repo.id == RepoQuery.by_id(repo.id, preload: :maintainers).id
    end
  end

  test "gets multiple repositories by id", %{repos: repos} do
    assert Enum.all?(RepoQuery.by_id(Enum.map(repos, &(&1.id)), preload: :maintainers), fn repo -> repo.id in Enum.map(repos, &(&1.id)) end)
  end

  test "gets single user repository", %{repos: repos} do
    for repo <- repos do
      assert repo.id == RepoQuery.user_repo(repo.owner.id, repo.name, preload: :maintainers).id
      assert repo.id == RepoQuery.user_repo(repo.owner.username, repo.name, preload: :maintainers).id
      assert repo.id == RepoQuery.user_repo(repo.owner, repo.name, preload: :maintainers).id
    end
  end

  test "gets multiple repositories from single user", %{repos: repos} do
    for {user, repos} <- Enum.group_by(repos, &(&1.owner)) do
      assert Enum.all?(RepoQuery.user_repos(user.id, preload: :maintainers), fn repo -> repo.id in Enum.map(repos, &(&1.id)) end)
      assert Enum.all?(RepoQuery.user_repos(user.username, preload: :maintainers), fn repo -> repo.id in Enum.map(repos, &(&1.id)) end)
      assert Enum.all?(RepoQuery.user_repos(user, preload: :maintainers), fn repo -> repo.id in Enum.map(repos, &(&1.id)) end)
    end
  end

  test "gets multiple repositories from multiple users", %{repos: repos} do
    users = Enum.map(repos, &(&1.owner))
    assert Enum.all?(RepoQuery.user_repos(Enum.map(users, &(&1.id)), preload: :maintainers), fn repo -> repo.id in Enum.map(repos, &(&1.id)) end)
    assert Enum.all?(RepoQuery.user_repos(Enum.map(users, &(&1.username)), preload: :maintainers), fn repo -> repo.id in Enum.map(repos, &(&1.id)) end)
    assert Enum.all?(RepoQuery.user_repos(users, preload: :maintainers), fn repo -> repo.id in Enum.map(repos, &(&1.id)) end)
  end

  test "gets single repository by path", %{repos: repos} do
    for repo <- repos do
      assert repo.id == RepoQuery.by_path(Repo.workdir(repo), preload: :maintainers).id
    end
  end

  #
  # Helpers
  #

  defp create_users(context) do
    users = Enum.take(Stream.repeatedly(fn -> User.create!(factory(:user)) end), 2)
    on_exit fn ->
      for user <- users do
        File.rmdir(Path.join(Repo.root_path, user.username))
      end
    end
    Map.put(context, :users, users)
  end

  defp create_repos(context) do
    repos = Enum.flat_map(context.users, &Enum.take(Stream.repeatedly(fn -> Repo.create!(factory(:repo, &1)) end), 3))
    on_exit fn ->
      for repo <- repos do
        File.rm_rf(Repo.workdir(repo))
      end
    end
    Map.put(context, :repos, repos)
  end
end
