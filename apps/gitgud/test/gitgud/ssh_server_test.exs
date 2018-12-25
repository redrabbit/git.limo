defmodule GitGud.SSHServerTest do
  use GitGud.DataCase
  use GitGud.DataFactory

  alias GitGud.User
  alias GitGud.Repo
  alias GitGud.SSHKey

  setup :create_user

  test "authenticates with valid credentials", %{user: user} do
    env_vars = [{"DISPLAY", "nothing:0"}, {"SSH_ASKPASS", Path.join([Path.dirname(__DIR__), "support", "ssh_askpass.exs"])}]
    args = ["-tt", "-o", "StrictHostKeyChecking=no", "-o", "PreferredAuthentications=password", "-o", "PubkeyAuthentication=no", "ssh://#{user.login}@localhost:9899"]
    output = "You are not allowed to start a shell.\r\nConnection to localhost closed.\r\n"
    assert {^output, 255} = System.cmd("ssh", args, env: env_vars, stderr_to_stdout: true)
  end

  test "fails to authenticates with invalid credentials", %{user: user} do
    env_vars = [{"DISPLAY", "nothing:0"}, {"SSH_ASKPASS", Path.join([Path.dirname(__DIR__), "support", "ssh_askpass.exs"])}]
    args = ["-tt", "-o", "StrictHostKeyChecking=no", "-o", "PreferredAuthentications=password", "-o", "PubkeyAuthentication=no", "ssh://#{user.login}_x@localhost:9899"]
    output = "Permission denied, please try again.\r\nPermission denied, please try again.\r\n#{user.login}_x@localhost: Permission denied (publickey,keyboard-interactive,password).\r\n"
    assert {^output, 255} = System.cmd("ssh", args, env: env_vars, stderr_to_stdout: true)
  end

  describe "when user has ssh public-key" do
    setup :create_ssh_key

    test "authenticates with valid public-key", %{user: user, id_rsa: id_rsa} do
      args = ["-tt", "-o", "StrictHostKeyChecking=no", "-o", "PreferredAuthentications=publickey", "-o", "PasswordAuthentication=no", "-i", id_rsa, "ssh://#{user.login}@localhost:9899"]
      output = "You are not allowed to start a shell.\r\nConnection to localhost closed.\r\n"
      assert {^output, 255} = System.cmd("ssh", args, stderr_to_stdout: true)
    end

    test "fails to authenticates with invalid public-key", %{user: user} do
      args = ["-tt", "-o", "StrictHostKeyChecking=no", "-o", "PreferredAuthentications=publickey", "-o", "PasswordAuthentication=no", "ssh://#{user.login}@localhost:9899"]
      output = "#{user.login}@localhost: Permission denied (publickey,keyboard-interactive,password).\r\n"
      assert {^output, 255} = System.cmd("ssh", args, stderr_to_stdout: true)
    end
  end

  describe "when repository exists" do
    setup [:create_ssh_key, :create_repo, :clone_from_github, :create_workdir]

    test "clones repository (~500 commits)", %{user: user, id_rsa: id_rsa, repo: repo, workdir: workdir} do
      assert {_output, 0} = System.cmd("git", ["clone", "--bare", "--quiet", "ssh://#{user.login}@localhost:9899/#{user.login}/#{repo.name}", workdir], env: [{"GIT_SSH_COMMAND", "ssh -i #{id_rsa}"}])
      assert {:ok, ref} = Repo.git_head(repo)
      output = GitRekt.Git.oid_fmt(ref.oid) <> "\n"
      assert {^output, 0} = System.cmd("git", ["rev-parse", "HEAD"], cd: workdir)
    end
  end

  describe "when repository is empty" do
    setup [:create_ssh_key, :create_repo, :create_workdir]

    test "pushes initial commit", %{user: user, id_rsa: id_rsa, repo: repo, workdir: workdir} do
      readme_content = "##{repo.name}\r\n\r\n#{repo.description}"
      assert {_output, 0} = System.cmd("git", ["init"], cd: workdir)
      File.write!(Path.join(workdir, "README.md"), readme_content)
      assert {_output, 0} = System.cmd("git", ["add", "README.md"], cd: workdir)
      assert {_output, 0} = System.cmd("git", ["commit", "README.md", "-m", "Initial commit"], cd: workdir)
      assert {_output, 0} = System.cmd("git", ["remote", "add", "origin", "ssh://#{user.login}@localhost:9899/#{user.login}/#{repo.name}"], cd: workdir)
      assert {_output, 0} = System.cmd("git", ["push", "--set-upstream", "origin", "--quiet", "master"], env: [{"GIT_SSH_COMMAND", "ssh -i #{id_rsa}"}], cd: workdir)
      assert {:ok, ref} = Repo.git_head(repo)
      assert {:ok, commit} = GitGud.GitReference.target(ref)
      assert {:ok, "Initial commit\n"} = GitGud.GitCommit.message(commit)
      assert {:ok, tree} = Repo.git_tree(commit)
      assert {:ok, tree_entry} = GitGud.GitTree.by_path(tree, "README.md")
      assert {:ok, blob} = GitGud.GitTreeEntry.target(tree_entry)
      assert {:ok, ^readme_content} = GitGud.GitBlob.content(blob)
    end

    test "pushes repository (~500 commits)", %{user: user, id_rsa: id_rsa, repo: repo, workdir: workdir} do
      assert {_output, 0} = System.cmd("git", ["clone", "--quiet", "https://github.com/almightycouch/gitgud.git", workdir])
      assert {_output, 0} = System.cmd("git", ["remote", "rm", "origin"], cd: workdir)
      assert {_output, 0} = System.cmd("git", ["remote", "add", "origin", "ssh://#{user.login}@localhost:9899/#{user.login}/#{repo.name}"], cd: workdir)
      assert {_output, 0} = System.cmd("git", ["push", "--set-upstream", "origin", "--quiet", "master"], env: [{"GIT_SSH_COMMAND", "ssh -i #{id_rsa}"}], cd: workdir)
      assert {:ok, ref} = Repo.git_head(repo)
      output = GitRekt.Git.oid_fmt(ref.oid) <> "\n"
      assert {^output, 0} = System.cmd("git", ["rev-parse", "HEAD"], cd: workdir)
    end
  end

  #
  # Helpers
  #

  defp create_user(context) do
    user = User.create!(factory(:user))
    on_exit fn ->
      File.rmdir(Path.join(Repo.root_path, user.login))
    end
    Map.put(context, :user, user)
  end

  defp create_ssh_key(context) do
    params = factory(:ssh_key_strong, context.user)
    ssh_key = SSHKey.create!(params)
    ssh_key_path = Path.join(System.tmp_dir!(), "#{context.user.login}_id_rsa")
    File.write!(ssh_key_path, params.__priv__)
    File.chmod!(ssh_key_path, 0o400)
    on_exit fn ->
      File.rm(ssh_key_path)
    end
    Map.merge(context, %{ssh_key: ssh_key, id_rsa: ssh_key_path})
  end

  defp create_repo(context) do
    repo = Repo.create!(factory(:repo, context.user))
    on_exit fn ->
      File.rm_rf(Repo.workdir(repo))
    end
    Map.put(context, :repo, repo)
  end

  defp clone_from_github(context) do
    File.rm_rf!(Repo.workdir(context.repo))
    {_output, 0} = System.cmd("git", ["clone", "--bare", "--quiet", "https://github.com/almightycouch/gitgud.git", context.repo.name], cd: Path.join(Repo.root_path(), context.user.login))
    context
  end

  defp create_workdir(context) do
    workdir = Path.join(System.tmp_dir!(), context.repo.name)
    File.mkdir!(workdir)
    on_exit fn ->
      File.rm_rf(workdir)
    end
    Map.put(context, :workdir, workdir)
  end
end
