defmodule GitGud.RepoTest do
  use GitGud.DataCase, async: true
  use GitGud.DataFactory

  alias GitGud.User
  alias GitGud.Repo

  setup_all do
    on_exit fn ->
      File.rm_rf!(Repo.root_path())
    end
  end

  setup :create_user

  test "creates a new repo with valid params", %{user: user} do
    assert {:ok, repo, _git_handle} = Repo.create(factory(:repo, user))
    assert File.dir?(Repo.workdir(repo))
  end

  test "fails to create a new repo with invalid name", %{user: user} do
    params = factory(:repo, user)
    assert {:error, changeset} = Repo.create(Map.delete(params, :name))
    assert "can't be blank" in errors_on(changeset).name
    assert {:error, changeset} = Repo.create(Map.update!(params, :name, &(&1<>"$")))
    assert "has invalid format" in errors_on(changeset).name
    assert {:error, changeset} = Repo.create(Map.update!(params, :name, &binary_part(&1, 0, 2)))
    assert "should be at least 3 character(s)" in errors_on(changeset).name
  end

  describe "when repo exists" do
    setup [:create_repo]

    test "fails to create a new repo with same name", %{user: user, repo: repo} do
      params = factory(:repo, user)
      assert {:error, changeset} = Repo.create(%{params|name: repo.name})
      assert "has already been taken" in errors_on(changeset).name
    end

    test "updates repo with valid params", %{repo: repo1} do
      assert {:ok, repo2} = Repo.update(repo1, name: "my-awesome-project", description: "This project is really awesome!")
      assert repo2.name == "my-awesome-project"
      assert repo2.description == "This project is really awesome!"
      refute File.dir?(Repo.workdir(repo1))
      assert File.dir?(Repo.workdir(repo2))
    end

    test "fails to update repo with invalid name", %{repo: repo} do
      assert {:error, changeset} = Repo.update(repo, name: "")
      assert "can't be blank" in errors_on(changeset).name
    end

    test "deletes repo", %{repo: repo1} do
      assert {:ok, repo2} = Repo.delete(repo1)
      assert repo2.__meta__.state == :deleted
    end
  end


  #
  # Helpers
  #

  defp create_user(context) do
    Map.put(context, :user, User.create!(factory(:user)))
  end

  defp create_repo(context) do
    {repo, _git_handle} = Repo.create!(factory(:repo, context.user))
    Map.put(context, :repo, repo)
  end
end
