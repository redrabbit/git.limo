defmodule GitGud.SSHServerTest do
  use GitGud.DataCase

  alias GitGud.User
  alias GitGud.Repo

  @user_dir Path.join(System.user_home!(), ".ssh")

  setup do
    {:ok, user} = User.register(name: "Mario Flach", username: "redrabbit", email: "m.flach@almightycouch.com", password: "test1234")
    {:ok, auth} = User.put_ssh_key(user, File.read!(Path.join(@user_dir, "id_rsa.pub")))

    File.mkdir!("priv/test")
    on_exit fn ->
      File.rm_rf!("priv/test")
    end

    {:ok, %{user: user, auth: auth, git_dir: "priv/test"}}
  end

  test "connects to server with ssh public key" do
    assert {:ok, _} = :ssh.connect('localhost', 8989, [user: 'redrabbit', user_dir: to_charlist(@user_dir), auth_methods: 'publickey'])
  end

  test "connects to server with password", %{user: user} do
    assert {:ok, _} = :ssh.connect('localhost', 8989, [user: to_charlist(user.username), password: 'test1234', auth_methods: 'password'])
  end

  test "fails to connect to server with invalid password", %{user: user} do
    assert {:error, reason} = :ssh.connect('localhost', 8989, [user: to_charlist(user.username), password: 'test1212', auth_methods: 'password'])
    assert 'Unable to connect using the available authentication methods' == reason
  end

  test "clones repository over ssh", %{user: user, git_dir: git_dir} do
    assert {:ok, repo, _pid} = Repo.create(path: "project-awesome", name: "My Awesome Project", owner_id: user.id)
    assert {msg, 0} = System.cmd("git", ["clone", "ssh://#{user.username}@localhost:8989/#{user.username}/#{repo.path}"], cd: git_dir, stderr_to_stdout: true)
    assert String.starts_with?(msg, "Cloning into '#{repo.path}'...\n")
    assert File.dir?(Path.join(git_dir, repo.path))
  end

  test "push commit to repository over ssh", %{user: user, git_dir: git_dir} do
    assert {:ok, repo, _pid} = Repo.create(path: "project-awesome", name: "My Awesome Project", owner_id: user.id)
    assert {_msg, 0} = System.cmd("git", ["clone", "ssh://#{user.username}@localhost:8989/#{user.username}/#{repo.path}"], cd: git_dir, stderr_to_stdout: true)
    repo_path = Path.join(git_dir, repo.path)
    assert File.dir?(repo_path)
    File.touch!(Path.join(repo_path, "README"))
    assert {_msg, 0} = System.cmd("git", ["add", "README"], cd: repo_path, stderr_to_stdout: true)
    assert {_msg, 0} = System.cmd("git", ["commit", "README", "-m", "Add README"], cd: repo_path, stderr_to_stdout: true)
    assert {_msg, 0} = System.cmd("git", ["push"], cd: repo_path, stderr_to_stdout: true)
  end
end
