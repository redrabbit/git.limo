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

  test "checks out and monitor agent", %{repo: repo} do
    assert {:ok, agent} = RepoPool.checkout_monitor(repo)
    assert :ok = GenServer.stop(agent)
    assert_receive {:DOWN, _mon, :process, ^agent, :normal}
    refute Process.alive?(agent)
  end

  test "iterates over available agents using round-robin once pool is saturated", %{repo: repo} do
    assert {:ok, agent1} = RepoPool.checkout(repo)
    assert {:ok, agent2} = RepoPool.checkout(repo)
    assert {:ok, agent3} = RepoPool.checkout(repo)
    assert {:ok, ^agent1} = RepoPool.checkout(repo)
    assert {:ok, ^agent2} = RepoPool.checkout(repo)
    assert {:ok, ^agent3} = RepoPool.checkout(repo)
    assert {:ok, ^agent1} = RepoPool.checkout(repo)
  end

  test "ensures pools are available via registry", %{repo: repo} do
    assert {:ok, pool} = RepoPool.start_pool(repo)
    assert [{^pool, nil}] = Registry.lookup(RepoRegistry, Path.join(repo.owner_login, repo.name))
    assert Process.alive?(pool)
  end

  test "ensures empty pools are terminated gracefully", %{repo: repo} do
    assert {:ok, agent} = RepoPool.checkout(repo)
    assert [{pool, nil}] = Registry.lookup(RepoRegistry, Path.join(repo.owner_login, repo.name))
    mon = Process.monitor(pool)
    assert :ok = GenServer.stop(agent)
    assert_receive {:DOWN, ^mon, :process, ^pool, :normal}
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
