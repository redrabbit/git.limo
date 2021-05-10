defmodule GitGud.RepoQueryTest do
  use GitGud.DataCase, async: true
  use GitGud.DataFactory

  alias GitGud.User
  alias GitGud.Repo
  alias GitGud.RepoStorage
  alias GitGud.RepoQuery

  setup [:create_users, :create_repos]

  test "gets single repository by id", %{repos: repos} do
    for repo <- repos do
      assert repo.id == RepoQuery.by_id(repo.id).id
    end
  end

  test "gets multiple repositories by ids", %{repos: repos} do
    results = RepoQuery.by_id(Enum.map(repos, &(&1.id)))
    assert Enum.count(results) == length(repos)
    assert Enum.all?(results, fn repo -> repo.id in Enum.map(repos, &(&1.id)) end)
  end

  test "gets single repository by path", %{repos: repos} do
    for repo <- repos do
      assert repo.id == RepoQuery.by_path(RepoStorage.workdir(repo), preload: :maintainers).id
    end
  end

  test "gets single user repository", %{repos: repos} do
    for repo <- repos do
      assert repo.id == RepoQuery.user_repo(repo.owner_id, repo.name).id
      assert repo.id == RepoQuery.user_repo(repo.owner_login, repo.name).id
      assert repo.id == RepoQuery.user_repo(repo.owner, repo.name).id
    end
  end

  test "gets multiple repositories from single user", %{repos: repos} do
    for {user, repos} <- Enum.group_by(repos, &(&1.owner)) do
      results = RepoQuery.user_repos(user.id)
      assert Enum.count(results) == length(repos)
      assert Enum.all?(results, fn repo -> repo.id in Enum.map(repos, &(&1.id)) end)
      results = RepoQuery.user_repos(user.login)
      assert Enum.count(results) == length(repos)
      assert Enum.all?(results, fn repo -> repo.id in Enum.map(repos, &(&1.id)) end)
      results = RepoQuery.user_repos(user)
      assert Enum.count(results) == length(repos)
      assert Enum.all?(results, fn repo -> repo.id in Enum.map(repos, &(&1.id)) end)
    end
  end

  test "gets multiple repositories from multiple users", %{repos: repos} do
    users = Enum.map(repos, &(&1.owner))
    results = RepoQuery.user_repos(Enum.map(users, &(&1.id)))
    assert Enum.count(results) == length(repos)
    assert Enum.all?(results, fn repo -> repo.id in Enum.map(repos, &(&1.id)) end)
    results = RepoQuery.user_repos(Enum.map(users, &(&1.login)))
    assert Enum.count(results) == length(repos)
    assert Enum.all?(results, fn repo -> repo.id in Enum.map(repos, &(&1.id)) end)
    results = RepoQuery.user_repos(users)
    assert Enum.count(results) == length(repos)
    assert Enum.all?(results, fn repo -> repo.id in Enum.map(repos, &(&1.id)) end)
  end

  test "gets single maintainer from repository", %{repos: repos} do
    for repo <- repos do
      admin = RepoQuery.maintainer(repo, repo.owner)
      assert admin.user == repo.owner
      assert admin.permission == "admin"
    end
  end

  test "gets multiple maintainers from repository", %{users: users, repos: repos} do
    for {user, repos} <- Enum.group_by(repos, &(&1.owner)) do
      for repo <- repos do
        maintainers =
          users
          |> Enum.reject(&(&1.id == user.id))
          |> Enum.map(&Repo.add_maintainer!(repo, user_id: &1.id))
        results = RepoQuery.maintainers(repo)
        assert length(results) == length(maintainers) + 1
        for maintainer <- results do
          if maintainer.user_id == user.id do
            assert maintainer.permission == "admin"
          else
            assert maintainer.permission == "read"
          end
        end
      end
    end
  end

  test "gets issues labels from repository", %{repos: repos} do
    for repo <- repos do
      assert RepoQuery.issue_labels(repo) == Enum.sort_by(repo.issue_labels, &(&1.name), :asc)
    end
  end

  #
  # Helpers
  #

  defp create_users(context) do
    users = Enum.take(Stream.repeatedly(fn -> User.create!(factory(:user)) end), 2)
    on_exit fn ->
      for user <- users do
        File.rmdir(Path.join(Keyword.fetch!(Application.get_env(:gitgud, RepoStorage), :git_root), user.login))
      end
    end
    Map.put(context, :users, users)
  end

  defp create_repos(context) do
    repos = Enum.flat_map(context.users, &Enum.take(Stream.repeatedly(fn -> Repo.create!(&1, factory(:repo)) end), 3))
    on_exit fn ->
      for repo <- repos do
        File.rm_rf(RepoStorage.workdir(repo))
      end
    end
    Map.put(context, :repos, repos)
  end
end
