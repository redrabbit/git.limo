defmodule GitGud.RepoPoolTest do
  use GitGud.DataCase, async: true
  use GitGud.DataFactory

  alias GitGud.User
  alias GitGud.Repo
  alias GitGud.RepoPool
  alias GitGud.RepoStorage

  setup [:create_user, :create_repo]

  test "starts repository agent", %{repo: repo} do
    assert {:ok, _pid} = RepoPool.start_agent(repo)
  end

  test "ensures pool cannot start duplicate repositories", %{repo: repo} do
    assert {:ok, pid} = RepoPool.start_agent(repo)
    assert {:error, {:already_started, ^pid}} = RepoPool.start_agent(repo)
  end

  test "fetches repository from registry", %{repo: repo} do
    assert {:ok, pid} = RepoPool.start_agent(repo)
    assert RepoPool.lookup(repo) == pid
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
