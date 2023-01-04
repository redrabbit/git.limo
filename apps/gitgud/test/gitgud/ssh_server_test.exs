defmodule GitGud.SSHServerTest do
  use GitGud.DataCase
  use GitGud.DataFactory

  alias GitRekt.Git
  alias GitRekt.GitRepo
  alias GitRekt.GitAgent

  alias GitGud.User
  alias GitGud.Repo
  alias GitGud.RepoStorage
  alias GitGud.SSHKey

  setup :create_user

  test "authenticates with valid credentials", %{user: user} do
    env_vars = [{"DISPLAY", "nothing:0"}, {"SSH_ASKPASS", Path.join([Path.dirname(__DIR__), "support", "ssh_askpass.exs"])}]
    args = ["-tt", "-o", "StrictHostKeyChecking=no", "-o", "PreferredAuthentications=password", "-o", "PubkeyAuthentication=no", "-o", "LogLevel=ERROR", "ssh://#{user.login}@localhost:9899"]
    assert {output, 255} = System.cmd("ssh", args, env: env_vars, stderr_to_stdout: true)
    assert output =~ "You are not allowed to start a shell."
  end

  test "fails to authenticates with invalid credentials", %{user: user} do
    env_vars = [{"DISPLAY", "nothing:0"}, {"SSH_ASKPASS", Path.join([Path.dirname(__DIR__), "support", "ssh_askpass.exs"])}]
    args = ["-tt", "-o", "StrictHostKeyChecking=no", "-o", "PreferredAuthentications=password", "-o", "PubkeyAuthentication=no", "-o", "LogLevel=ERROR", "ssh://#{user.login}_x@localhost:9899"]
    assert {output, 255} = System.cmd("ssh", args, env: env_vars, stderr_to_stdout: true)
    assert output =~ "Permission denied, please try again."
  end

  @tag timeout: 5_000
  test "disallows scp", %{user: user} do
    env_vars = [{"DISPLAY", "nothing:0"}, {"SSH_ASKPASS", Path.join([Path.dirname(__DIR__), "support", "ssh_askpass.exs"])}]
    args = ["-P", "9899", "mix.exs", "#{user.login}@localhost:/tmp/mix.exs"]
    assert {output, 255} = System.cmd("scp", args, env: env_vars, stderr_to_stdout: true)
    assert output =~ "subsystem request failed on channel"
  end

  describe "when user has ssh public-key" do
    setup :create_ssh_key

    test "authenticates with valid public-key", %{user: user, id_rsa: id_rsa} do
      args = ["-tt", "-o", "StrictHostKeyChecking=no", "-o", "PreferredAuthentications=publickey", "-o", "PasswordAuthentication=no", "-o", "LogLevel=ERROR", "-i", id_rsa, "ssh://#{user.login}@localhost:9899"]
      assert {output, 255} = System.cmd("ssh", args, stderr_to_stdout: true)
      assert output =~ "You are not allowed to start a shell."
    end

    test "fails to authenticates with invalid public-key", %{user: user} do
      args = ["-tt", "-o", "StrictHostKeyChecking=no", "-o", "PreferredAuthentications=publickey", "-o", "PasswordAuthentication=no", "-o", "LogLevel=ERROR", "ssh://#{user.login}@localhost:9899"]
      assert {output, 255} = System.cmd("ssh", args, stderr_to_stdout: true)
      assert output =~ "Permission denied (publickey,keyboard-interactive,password)."
    end
  end

  describe "when repository is empty" do
    setup [:create_ssh_key, :create_repo, :create_workdir]

    @tag :skip
    test "pushes initial commit", %{user: user, id_rsa: id_rsa, repo: repo, workdir: workdir} do
      readme_content = "##{repo.name}\r\n\r\n#{repo.description}"
      assert {_output, 0} = System.cmd("git", ["init", "-b", "main"], cd: workdir)
      assert {_output, 0} = System.cmd("git", ["config", "user.name", "testbot"], cd: workdir)
      assert {_output, 0} = System.cmd("git", ["config", "user.email", "no-reply@git.limo"], cd: workdir)
      File.write!(Path.join(workdir, "README.md"), readme_content)
      assert {_output, 0} = System.cmd("git", ["add", "README.md"], cd: workdir)
      assert {_output, 0} = System.cmd("git", ["commit", "README.md", "-m", "Initial commit"], cd: workdir)
      assert {_output, 0} = System.cmd("git", ["remote", "add", "origin", "ssh://#{user.login}@localhost:9899/#{user.login}/#{repo.name}.git"], cd: workdir)
      assert {_output, 0} = System.cmd("git", ["push", "--set-upstream", "origin", "--quiet", "main"], env: [{"GIT_SSH_COMMAND", "ssh -i #{id_rsa}"}], cd: workdir)
      assert {:ok, agent} = GitRepo.get_agent(repo)
      assert {:ok, head} = GitAgent.head(agent)
      assert {:ok, commit} = GitAgent.peel(agent, head)
      assert {:ok, "Initial commit\n"} = GitAgent.commit_message(agent, commit)
      assert {:ok, tree} = GitAgent.tree(agent, commit)
      assert {:ok, tree_entry} = GitAgent.tree_entry_by_path(agent, tree, "README.md")
      assert {:ok, blob} = GitAgent.peel(agent, tree_entry)
      assert {:ok, ^readme_content} = GitAgent.blob_content(agent, blob)
    end

    @tag :skip
    test "pushes repository", %{user: user, id_rsa: id_rsa, repo: repo, workdir: workdir} do
      assert {_output, 0} = System.cmd("git", ["clone", "--quiet", "https://github.com/almightycouch/gitgud.git", workdir])
      assert {_output, 0} = System.cmd("git", ["branch", "-m", "master", "main"], cd: workdir)
      assert {_output, 0} = System.cmd("git", ["remote", "rm", "origin"], cd: workdir)
      assert {_output, 0} = System.cmd("git", ["remote", "add", "origin", "ssh://#{user.login}@localhost:9899/#{user.login}/#{repo.name}.git"], cd: workdir)
      assert {_output, 0} = System.cmd("git", ["push", "--set-upstream", "origin", "--quiet", "main"], env: [{"GIT_SSH_COMMAND", "ssh -i #{id_rsa}"}], cd: workdir)
      assert {:ok, agent} = GitRepo.get_agent(repo)
      assert {:ok, head} = GitAgent.head(agent)
      output = Git.oid_fmt(head.oid) <> "\n"
      assert {^output, 0} = System.cmd("git", ["rev-parse", "HEAD"], cd: workdir)
    end
  end

  describe "when repository exists" do
    setup [:create_ssh_key, :create_repo, :clone_from_github, :create_workdir]

    @tag :skip
    test "clones repository", %{user: user, id_rsa: id_rsa, repo: repo, workdir: workdir} do
      assert {_output, 0} = System.cmd("git", ["clone", "--bare", "--quiet", "ssh://#{user.login}@localhost:9899/#{user.login}/#{repo.name}.git", workdir], env: [{"GIT_SSH_COMMAND", "ssh -i #{id_rsa}"}])
      assert {:ok, agent} = GitRepo.get_agent(repo)
      assert {:ok, head} = GitAgent.head(agent)
      output = Git.oid_fmt(head.oid) <> "\n"
      assert {^output, 0} = System.cmd("git", ["rev-parse", "HEAD"], cd: workdir)
    end
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

  defp create_ssh_key(context) do
    params = factory(:ssh_key_strong, context.user)
    ssh_key = SSHKey.create!(context.user, params)
    ssh_key_path = Path.join(System.tmp_dir!(), "#{context.user.login}_id_rsa")
    File.write!(ssh_key_path, params.__priv__)
    File.chmod!(ssh_key_path, 0o400)
    on_exit fn ->
      File.rm(ssh_key_path)
    end
    Map.merge(context, %{ssh_key: ssh_key, id_rsa: ssh_key_path})
  end

  defp create_repo(context) do
    repo = Repo.create!(context.user, factory(:repo))
    on_exit fn ->
      File.rm_rf(RepoStorage.workdir(repo))
    end
    Map.put(context, :repo, repo)
  end

  defp clone_from_github(context) do
    File.rm_rf!(RepoStorage.workdir(context.repo))
    {_output, 0} = System.cmd("git", ["clone", "--bare", "--quiet", "https://github.com/almightycouch/gitgud.git", context.repo.name], cd: Path.join(Keyword.fetch!(Application.get_env(:gitgud, RepoStorage), :git_root), context.user.login))
    :ok
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
