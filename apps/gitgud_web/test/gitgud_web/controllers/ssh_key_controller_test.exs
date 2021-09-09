defmodule GitGud.Web.SSHKeyControllerTest do
  use GitGud.Web.ConnCase, async: true
  use GitGud.Web.DataFactory

  alias GitGud.User
  alias GitGud.SSHKey

  alias GitGud.Web.LayoutView

  setup :create_user

  test "renders ssh authentication key creation form if authenticated", %{conn: conn, user: user} do
    conn = Plug.Test.init_test_session(conn, user_id: user.id)
    conn = get(conn, Routes.ssh_key_path(conn, :new))
    assert {:ok, html} = Floki.parse_document(html_response(conn, 200))
    assert Floki.text(Floki.find(html, "title")) == LayoutView.title(conn)
  end

  test "fails to render ssh authentication key creation form if not authenticated", %{conn: conn} do
    conn = get(conn, Routes.ssh_key_path(conn, :new))
    assert {:ok, html} = Floki.parse_document(html_response(conn, 401))
    assert Floki.text(Floki.find(html, "title")) == Plug.Conn.Status.reason_phrase(401)
  end

  test "creates ssh authentication key with valid params", %{conn: conn, user: user} do
    ssh_key_params = factory(:ssh_key)
    conn = Plug.Test.init_test_session(conn, user_id: user.id)
    conn = post(conn, Routes.ssh_key_path(conn, :create), ssh_key: ssh_key_params)
    assert get_flash(conn, :info) == "SSH key '#{ssh_key_params.name}' added."
    assert redirected_to(conn) == Routes.ssh_key_path(conn, :index)
  end

  test "fails to create ssh authentication key with invalid public key", %{conn: conn, user: user} do
    ssh_key_params = factory(:ssh_key)
    conn = Plug.Test.init_test_session(conn, user_id: user.id)
    conn = post(conn, Routes.ssh_key_path(conn, :create), ssh_key: Map.update!(ssh_key_params, :data, &binary_part(&1, 0, 12)))
    assert get_flash(conn, :error) == "Something went wrong! Please check error(s) below."
    assert {:ok, html} = Floki.parse_document(html_response(conn, 400))
    assert Floki.text(Floki.find(html, "title")) == LayoutView.title(conn)
  end

  describe "when ssh authentication keys exist" do
    setup :create_ssh_keys

    test "renders user ssh authentication keys", %{conn: conn, user: user, ssh_keys: ssh_keys} do
      conn = Plug.Test.init_test_session(conn, user_id: user.id)
      conn = get(conn, Routes.ssh_key_path(conn, :index))
      assert {:ok, html} = Floki.parse_document(html_response(conn, 200))
      assert Floki.text(Floki.find(html, "title")) == LayoutView.title(conn)
      html_ssh_keys = Enum.map(Floki.find(html, ".card .card-header-title"), &String.trim(Floki.text(&1)))
      for ssh_key <- ssh_keys do
        assert ssh_key.name in html_ssh_keys
      end
    end

    test "deletes keys", %{conn: conn, user: user, ssh_keys: ssh_keys} do
      conn = Plug.Test.init_test_session(conn, user_id: user.id)
      for ssh_key <- ssh_keys do
        conn = delete(conn, Routes.ssh_key_path(conn, :delete), ssh_key: %{id: to_string(ssh_key.id)})
        assert get_flash(conn, :info) == "SSH key '#{ssh_key.name}' deleted."
        assert redirected_to(conn) == Routes.ssh_key_path(conn, :index)
      end
    end
  end

  #
  # Helpers
  #

  defp create_user(context) do
    Map.put(context, :user, User.create!(factory(:user)))
  end

  defp create_ssh_keys(context) do
    ssh_keys = Stream.repeatedly(fn -> SSHKey.create!(context.user, factory(:ssh_key)) end)
    Map.put(context, :ssh_keys, Enum.take(ssh_keys, 2))
  end
end
