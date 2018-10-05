defmodule GitGud.RepoTest do
  use GitGud.DataCase

  alias GitRekt.Git

  alias GitGud.User
  alias GitGud.Repo
  alias GitGud.RepoQuery

  @valid_attrs %{name: "project-awesome", description: "Awesome things are going on here!"}

  setup do
    user =
      User.register!(
        name: "Mario Flach",
        username: "redrabbit",
        email: "m.flach@almightycouch.com",
        password: "test1234"
      )

    on_exit(fn ->
      File.rm_rf!(Path.join(Application.get_env(:gitgud, :git_dir), user.username))
    end)

    {:ok, %{user: user}}
  end

  test "creates a bare repository", %{user: user} do
    params = Map.put(@valid_attrs, :owner_id, user.id)
    assert {:ok, repo, ref} = Repo.create(params)
    assert File.dir?(Repo.workdir(repo))
    assert Git.repository_bare?(ref)
  end

  test "fails to create a repository with invalid params", %{user: user} do
    params = Map.put(@valid_attrs, :owner_id, user.id)
    assert {:error, changeset} = Repo.create(%{params | name: "foo$bar"})
    assert "has invalid format" in errors_on(changeset).name
    assert {:error, changeset} = Repo.create(%{params | name: "xy"})
    assert "should be at least 3 character(s)" in errors_on(changeset).name
  end

  test "fails to create two repositories with same path", %{user: user} do
    params = Map.put(@valid_attrs, :owner_id, user.id)
    assert {:ok, _repo, _pid} = Repo.create(params)
    assert {:error, changeset} = Repo.create(params)
    assert "has already been taken" in errors_on(changeset).name
  end

  test "gets all repositories owned by a user", %{user: user} do
    params = Map.put(@valid_attrs, :owner_id, user.id)

    repos =
      1..5
      |> Enum.map(fn i -> update_in(params.name, &"#{&1}-#{i}") end)
      |> Enum.map(&Repo.create!/1)
      |> Enum.map(&elem(&1, 0))
      |> DB.preload(:owner)

    assert repos == RepoQuery.user_repositories(user)
  end

  test "gets a single user repository", %{user: user} do
    params = Map.put(@valid_attrs, :owner_id, user.id)
    assert {:ok, repo, _pid} = Repo.create(params)
    repo = DB.preload(repo, :owner)
    assert ^repo = RepoQuery.user_repository(user, repo.name)
  end

  test "updates a repository", %{user: user} do
    params = Map.put(@valid_attrs, :owner_id, user.id)
    assert {:ok, old_repo, _pid} = Repo.create(params)
    assert {:ok, new_repo} = Repo.update(old_repo, name: "project-super-awesome")
    refute File.dir?(Repo.workdir(old_repo))
    assert File.dir?(Repo.workdir(new_repo))
  end

  test "deletes a repository", %{user: user} do
    params = Map.put(@valid_attrs, :owner_id, user.id)
    assert {:ok, repo, _pid} = Repo.create(params)
    assert {:ok, repo} = Repo.delete(repo)
    refute File.dir?(Repo.workdir(repo))
  end

  test "ensures user has read and write permissions to own repository", %{user: user} do
    params = Map.put(@valid_attrs, :owner_id, user.id)
    assert {:ok, repo, _pid} = Repo.create(params)
    assert Repo.can_read?(repo, user)
    assert Repo.can_write?(repo, user)
  end
end
