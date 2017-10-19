defmodule GitGud.SSHServerTest do
  use GitGud.DataCase

  alias GitGud.User

  @user_dir Path.join(System.user_home!(), ".ssh")

  setup do
    {:ok, user} = User.register(name: "Mario Flach", username: "redrabbit", email: "m.flach@almightycouch.com", password: "test1234")
    {:ok, auth} = User.put_ssh_key(user, File.read!(Path.join(@user_dir, "id_rsa.pub")))
    {:ok, %{user: user, auth: auth}}
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
end
