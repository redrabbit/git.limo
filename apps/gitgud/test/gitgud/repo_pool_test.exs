defmodule GitGud.RepoPoolTest do
  use GitGud.DataCase, async: false
  use GitGud.DataFactory

  alias GitGud.User
  alias GitGud.Repo
  alias GitGud.RepoPool
  alias GitGud.RepoRegistry
  alias GitGud.RepoStorage

  setup [:create_user, :create_repo]

  test "starts pool for a repository", %{repo: repo} do
    assert {:ok, pool} = RepoPool.start_pool(repo)
    assert Enum.empty?(DynamicSupervisor.which_children(pool))
  end

  test "fails to start multiple pool for a single repository", %{repo: repo} do
    assert {:ok, pool} = RepoPool.start_pool(repo)
    assert {:error, {:already_started, ^pool}} = RepoPool.start_pool(repo)
  end

  test "starts an agent within a pool", %{repo: repo} do
    assert {:ok, agent} = RepoPool.start_agent(repo)
    assert Process.alive?(agent)
  end

  test "fails to starts more than three agent within a pool", %{repo: repo} do
    assert {:ok, _} = RepoPool.start_agent(repo)
    assert {:ok, _} = RepoPool.start_agent(repo)
    assert {:ok, _} = RepoPool.start_agent(repo)
    assert {:error, :max_children} = RepoPool.start_agent(repo)
  end

  test "iterates over available agents using round-robin once pool is saturated", %{repo: repo} do
    assert {:ok, agent1} = RepoPool.get_or_create(repo)
    assert {:ok, agent2} = RepoPool.get_or_create(repo)
    assert {:ok, agent3} = RepoPool.get_or_create(repo)
    assert {:ok, ^agent1} = RepoPool.get_or_create(repo)
    assert {:ok, ^agent2} = RepoPool.get_or_create(repo)
    assert {:ok, ^agent3} = RepoPool.get_or_create(repo)
    assert {:ok, ^agent1} = RepoPool.get_or_create(repo)
  end

  test "ensures pools are available via registry", %{repo: repo} do
    assert {:ok, _agent} = RepoPool.get_or_create(repo)
    assert [{pool, nil}] = Registry.lookup(RepoRegistry, Path.join(repo.owner_login, repo.name))
    assert Process.alive?(pool)
  end

  test "ensures empty pools are terminated gracefully", %{repo: repo} do
    assert {:ok, agent} = RepoPool.get_or_create(repo)
    assert [{pool, nil}] = Registry.lookup(RepoRegistry, Path.join(repo.owner_login, repo.name))
    assert :ok = GenServer.stop(agent)
    Process.sleep(20)
    refute Process.alive?(pool)
  end

  #
  # Helpers
  #

  defp create_user(context) do
    user = User.create!(factory(:user))
    on_exit fn ->
      File.rmdir(Path.join(Keyword.fetch!(Application.get_env(:gitgud, RepoStorage), :git_root), user.login))
    end
    Map.put(context, :user, user)
  end

  defp create_repo(context) do
    repo = Repo.create!(context.user, factory(:repo))
    on_exit fn ->
      File.rm_rf(RepoStorage.workdir(repo))
    end
    Map.put(context, :repo, repo)
  end
end
