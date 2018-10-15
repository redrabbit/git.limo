defmodule GitGud.RepoQueryTest do
  use GitGud.DataCase, async: true
  use GitGud.DataFactory

  alias GitGud.User
  alias GitGud.Repo
  alias GitGud.RepoQuery

  setup_all do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(GitGud.DB)
    Ecto.Adapters.SQL.Sandbox.mode(GitGud.DB, :auto)
  end

  setup_all [:create_users, :create_repos]

  test "gets single repository by id", %{repos: repos} do
    for repo <- repos do
      assert repo == RepoQuery.by_id(repo.id, preload: :maintainers)
    end
  end

  test "gets multiple repositories by id", %{repos: repos} do
    assert Enum.all?(RepoQuery.by_id(Enum.map(repos, &(&1.id)), preload: :maintainers), &(&1 in repos))
  end

  test "gets single user repository", %{repos: repos} do
    for repo <- repos do
      assert repo == RepoQuery.user_repo(repo.owner.id, repo.name, preload: :maintainers)
      assert repo == RepoQuery.user_repo(repo.owner.username, repo.name, preload: :maintainers)
      assert repo == RepoQuery.user_repo(repo.owner, repo.name, preload: :maintainers)
    end
  end

  test "gets multiple repositories from single user", %{repos: repos} do
    for {user, repos} <- Enum.group_by(repos, &(&1.owner)) do
      assert Enum.all?(RepoQuery.user_repos(user.id, preload: :maintainers), &(&1 in repos))
      assert Enum.all?(RepoQuery.user_repos(user.username, preload: :maintainers), &(&1 in repos))
      assert Enum.all?(RepoQuery.user_repos(user, preload: :maintainers), &(&1 in repos))
    end
  end

  test "gets multiple repositories from multiple users", %{repos: repos} do
    users = Enum.map(repos, &(&1.owner))
    assert Enum.all?(RepoQuery.user_repos(Enum.map(users, &(&1.id)), preload: :maintainers), &(&1 in repos))
    assert Enum.all?(RepoQuery.user_repos(Enum.map(users, &(&1.username)), preload: :maintainers), &(&1 in repos))
    assert Enum.all?(RepoQuery.user_repos(users, preload: :maintainers), &(&1 in repos))
  end

  test "gets single repository by path", %{repos: repos} do
    for repo <- repos do
      assert repo == RepoQuery.by_path(Repo.workdir(repo), preload: :maintainers)
    end
  end

  #
  # Helpers
  #

  defp create_users(context) do
    users = Enum.take(Stream.repeatedly(fn -> User.create!(factory(:user)) end), 2)
    Map.put(context, :users, users)
  end

  defp create_repos(context) do
    repos = Enum.flat_map(context.users, &Enum.take(Stream.repeatedly(fn -> elem(Repo.create!(factory(:repo, &1)), 0) end), 3))
    on_exit fn ->
      for repo <- repos do
        File.rm_rf!(Repo.workdir(repo))
      end
    end
    Map.put(context, :repos, repos)
  end
end
