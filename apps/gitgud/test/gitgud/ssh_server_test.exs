defmodule GitGud.SSHServerTest do
  use GitGud.DataCase
  use GitGud.DataFactory

  alias GitGud.User
  alias GitGud.SSHKey
  alias GitGud.Repo

  setup :create_user

  test "authenticates user with credentials", %{user: user} do
    env_vars = [{"DISPLAY", "nothing:0"}, {"SSH_ASKPASS", Path.expand(Path.join([Path.dirname(__DIR__), "support", "ssh_askpass.exs"]))}]
    args = ["-tt", "-o", "StrictHostKeyChecking=no", "-o", "PreferredAuthentications=password", "-o", "PubkeyAuthentication=no", "ssh://#{user.login}@localhost:9899"]
    output = "You are not allowed to start a shell.\r\nConnection to localhost closed.\r\n"
    assert {^output, 255} = System.cmd("ssh", args, env: env_vars, stderr_to_stdout: true)
  end

  test "fails to authenticates user with invalid credentials", %{user: user} do
    env_vars = [{"DISPLAY", "nothing:0"}, {"SSH_ASKPASS", Path.expand(Path.join([Path.dirname(__DIR__), "support", "ssh_askpass.exs"]))}]
    args = ["-tt", "-o", "StrictHostKeyChecking=no", "-o", "PreferredAuthentications=password", "-o", "PubkeyAuthentication=no", "ssh://#{user.login}_x@localhost:9899"]
    output = "Permission denied, please try again.\r\nPermission denied, please try again.\r\n#{user.login}_x@localhost: Permission denied (publickey,keyboard-interactive,password).\r\n"
    assert {^output, 255} = System.cmd("ssh", args, env: env_vars, stderr_to_stdout: true)
  end

  describe "when user has ssh public-key" do
    setup :create_ssh_key

    test "authenticates user with public-key", %{user: user, id_rsa: id_rsa} do
      args = ["-tt", "-o", "StrictHostKeyChecking=no", "-o", "PreferredAuthentications=publickey", "-o", "PasswordAuthentication=no", "-i", id_rsa, "ssh://#{user.login}@localhost:9899"]
      output = "You are not allowed to start a shell.\r\nConnection to localhost closed.\r\n"
      assert {^output, 255} = System.cmd("ssh", args, stderr_to_stdout: true)
    end

    test "fails to authenticates user with invalid public-key", %{user: user} do
      args = ["-tt", "-o", "StrictHostKeyChecking=no", "-o", "PreferredAuthentications=publickey", "-o", "PasswordAuthentication=no", "ssh://#{user.login}@localhost:9899"]
      output = "#{user.login}@localhost: Permission denied (publickey,keyboard-interactive,password).\r\n"
      assert {^output, 255} = System.cmd("ssh", args, stderr_to_stdout: true)
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

# defp create_repo(context) do
#   repo = Repo.create!(factory(:repo, context.user))
#   on_exit fn ->
#     File.rm_rf(Repo.workdir(repo))
#   end
#   Map.put(context, :repo, repo)
# end
end
