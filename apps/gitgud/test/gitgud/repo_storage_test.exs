defmodule GitGud.RepoStorageTest do
  use GitGud.DataCase, async: true
  use GitGud.DataFactory

  alias GitRekt.Git

  alias GitGud.User
  alias GitGud.Repo
  alias GitGud.RepoStorage

  setup [:create_user, :create_repo]

  test "initialize Git repository", %{repo: repo} do
    assert {:ok, handle} = RepoStorage.init(repo, false)
    assert File.dir?(RepoStorage.workdir(repo))
    refute Git.repository_bare?(handle)
    File.rm_rf(RepoStorage.workdir(repo))
  end

  test "initialize bare Git repository", %{repo: repo} do
    assert {:ok, handle} = RepoStorage.init(repo, true)
    assert File.dir?(RepoStorage.workdir(repo))
    assert Git.repository_bare?(handle)
    File.rm_rf(RepoStorage.workdir(repo))
  end

  test "ensures workdir is valid", %{user: user, repo: repo} do
    assert RepoStorage.workdir(repo) == Path.join([Application.fetch_env!(:gitgud, :git_root), user.login, repo.name])
  end


  describe "when Git repository exists" do
    setup :init_repo

    test "moves repository", %{repo: old_repo} do
      changeset = Ecto.Changeset.change(old_repo, name: old_repo.name <> "_new")
      assert {:ok, new_repo} = DB.update(changeset)
      assert {:ok, new_workdir} = RepoStorage.rename(new_repo, old_repo)
      assert RepoStorage.workdir(new_repo) == new_workdir
      refute File.dir?(RepoStorage.workdir(old_repo))
      assert File.dir?(RepoStorage.workdir(new_repo))
      File.rm_rf(RepoStorage.workdir(new_repo))
    end

    test "removes repository", %{repo: repo} do
      assert {:ok, [workdir|_files]} = RepoStorage.cleanup(repo)
      assert RepoStorage.workdir(repo) == workdir
      refute File.dir?(workdir)
    end
  end

  #
  # Helpers
  #

  defp create_user(context) do
    user = User.create!(factory(:user))
    on_exit fn ->
      File.rmdir(Path.join(Application.fetch_env!(:gitgud, :git_root), user.login))
    end
    Map.put(context, :user, user)
  end

  defp create_repo(context) do
    repo = Repo.create!(factory(:repo, context.user), init: false)
    Map.put(context, :repo, repo)
  end

  defp init_repo(context) do
    {:ok, _handle} = RepoStorage.init(context.repo, true)
    on_exit fn ->
      File.rm_rf(RepoStorage.workdir(context.repo))
    end
  end
end
