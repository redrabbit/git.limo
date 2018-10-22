defmodule GitGud.AuthorizationTest do
  use GitGud.DataCase, async: true
  use GitGud.DataFactory

  alias GitGud.Authorization

  alias GitGud.User
  alias GitGud.UserQuery
  alias GitGud.Repo
  alias GitGud.RepoQuery

  setup [:create_users, :create_repos]

  test "anon can query public repositories", %{users: users} do
    assert Enum.all?(RepoQuery.user_repos(users), &(&1.public))
  end

  test "anon has :read access to public repositories", %{repos: repos} do
    for repo <- Enum.filter(repos, &(&1.public)) do
      assert Authorization.authorized?(nil, repo, :read)
    end
  end

  test "anon does not have :read access to private repositories", %{repos: repos} do
    for repo <- Enum.filter(repos, &(!&1.public)) do
      refute Authorization.authorized?(nil, repo, :read)
    end
  end

  test "anon does not have :write access to public repositories", %{repos: repos} do
    for repo <- Enum.filter(repos, &(&1.public)) do
      refute Authorization.authorized?(nil, repo, :write)
    end
  end

  test "anon does not have :write access to private repositories", %{repos: repos} do
    for repo <- Enum.filter(repos, &(!&1.public)) do
      refute Authorization.authorized?(nil, repo, :write)
    end
  end

  test "user can query private repositories he owns", %{users: users} do
    for user <- users do
      {public, private} =
        user
        |> RepoQuery.user_repos(viewer: user)
        |> Enum.split_with(&(&1.public))
      assert length(public) == 1
      assert length(private) == 1
      assert Enum.all?(private, &(user.id == &1.owner_id))
    end
  end

  test "user can query private repositories he maintains", %{users: users} do
    for user <- users do
      {public, private} =
        users
        |> RepoQuery.user_repos(viewer: user, preload: :maintainers)
        |> Enum.split_with(&(&1.public))
      assert length(public) == 3
      assert length(private) == 2
      assert Enum.all?(private, &(user in &1.maintainers))
    end
  end

  test "user can preload private repositories he maintains", %{users: users} do
    for user <- users do
      {public, private} =
        users
        |> Enum.map(&(&1.id))
        |> UserQuery.by_id(viewer: user, preload: [repos: :maintainers])
        |> Enum.flat_map(&(&1.repos))
        |> Enum.split_with(&(&1.public))
      assert length(public) == 3
      assert length(private) == 2
      assert Enum.all?(private, &(user in &1.maintainers))
    end
  end

  test "user can preload private repositories he owns", %{users: users} do
    for user <- users do
      {public, private} =
        user.id
        |> UserQuery.by_id(viewer: user, preload: :repos)
        |> Map.fetch!(:repos)
        |> Enum.split_with(&(&1.public))
      assert length(public) == 1
      assert length(private) == 1
      assert Enum.all?(private, &(user.id  == &1.owner_id))
    end
  end

  test "user has :read access to private repositories he owns", %{repos: repos} do
    for repo <- Enum.filter(repos, &(!&1.public)) do
      assert Authorization.authorized?(repo.owner, repo, :read)
    end
  end

  test "user has :write access to private repositories he owns", %{repos: repos} do
    for repo <- Enum.filter(repos, &(!&1.public)) do
      assert Authorization.authorized?(repo.owner, repo, :write)
    end
  end

  test "user has :read access to private repositories he maintains", %{repos: repos} do
    for repo <- Enum.filter(repos, &(!&1.public)) do
      assert Enum.all?(repo.maintainers, &Authorization.authorized?(&1, repo, :read))
    end
  end

  test "user has :write access to private repositories he maintains", %{repos: repos} do
    for repo <- Enum.filter(repos, &(!&1.public)) do
      assert Enum.all?(repo.maintainers, &Authorization.authorized?(&1, repo, :write))
    end
  end

  test "filters repositories based on user and action", %{repos: repos} do
    {public, private} = Enum.split_with(repos, &(&1.public))
    assert Authorization.filter(nil, public, :read) == public
    assert Enum.empty?(Authorization.filter(nil, private, :read))
    assert Enum.empty?(Authorization.filter(nil, public, :write))
    assert Enum.empty?(Authorization.filter(nil, private, :write))
  end

  #
  # Helpers
  #

  defp create_users(context) do
    users = Enum.take(Stream.repeatedly(fn -> User.create!(factory(:user)) end), 3)
    on_exit fn ->
      for user <- users do
        File.rmdir(Path.join(Repo.root_path, user.username))
      end
    end
    Map.put(context, :users, users)
  end

  defp create_repos(context) do
    {repos, _last_user} =
      Enum.flat_map_reduce(context.users, nil, fn user, last_user ->
        {repo1, _git_handle} = Repo.create!(Map.put(factory(:repo, user), :public, true))
        {repo2, _git_handle} = Repo.create!(Map.put(factory(:repo, user), :public, false))
        maintainers = if last_user, do: [last_user|repo2.maintainers], else: [List.last(context.users)|repo2.maintainers]
        {[repo1, Repo.update!(repo2, maintainers: maintainers)], user}
      end)
    on_exit fn ->
      for repo <- repos do
        File.rm_rf(Repo.workdir(repo))
      end
    end
    Map.put(context, :repos, repos)
  end
end
