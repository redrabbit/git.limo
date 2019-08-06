defmodule GitGud.Web.MaintainerControllerTest do
  use GitGud.Web.ConnCase, async: true
  use GitGud.Web.DataFactory

  alias GitGud.DB
  alias GitGud.User
  alias GitGud.Repo
  alias GitGud.RepoStorage
  alias GitGud.Maintainer

  setup [:create_users, :create_repo]

  test "renders repo maintainer creation settings if authenticated", %{conn: conn, users: [user1, _user2], repo: repo} do
    conn = Plug.Test.init_test_session(conn, user_id: user1.id)
    conn = get(conn, Routes.maintainer_path(conn, :index, user1, repo))
    assert html_response(conn, 200) =~ ~s(<h2 class="subtitle">Maintainers</h2>)
  end

  test "fails to render repository maintainer settings if not authenticated", %{conn: conn, users: [user1, _user2], repo: repo} do
    conn = get(conn, Routes.maintainer_path(conn, :index, user1, repo))
    assert html_response(conn, 401) =~ "Unauthorized"
  end

  test "creates repository maintainer with valid params", %{conn: conn, users: [user1, user2], repo: repo} do
    conn = Plug.Test.init_test_session(conn, user_id: user1.id)
    conn = post(conn, Routes.maintainer_path(conn, :create, user1, repo), maintainer: %{user_id: to_string(user2.id)})
    assert get_flash(conn, :info) == "Maintainer '#{user2.login}' added."
    assert redirected_to(conn) == Routes.maintainer_path(conn, :index, user1, repo)
  end

  describe "when repository maintainer exist" do
    setup :create_maintainer

    test "renders maintainers", %{conn: conn, users: [user1, user2], repo: repo} do
      conn = Plug.Test.init_test_session(conn, user_id: user1.id)
      conn = get(conn, Routes.maintainer_path(conn, :index, user1, repo))
      assert html_response(conn, 200) =~ ~s(<h2 class="subtitle">Maintainers</h2>)
      assert html_response(conn, 200) =~ user2.login
    end

    test "updates maintainer permission with valid permission", %{conn: conn, users: [user1, user2], repo: repo, maintainer: maintainer} do
      conn = Plug.Test.init_test_session(conn, user_id: user1.id)
      conn = put(conn, Routes.maintainer_path(conn, :update, user1, repo), maintainer: %{id: to_string(maintainer.id), permission: "write"})
      assert get_flash(conn, :info) == "Maintainer '#{user2.login}' permission set to 'write'."
      assert redirected_to(conn) == Routes.maintainer_path(conn, :index, user1, repo)
    end

    test "fails to update maintainer with invalid permission", %{conn: conn, users: [user1, _user2], repo: repo, maintainer: maintainer} do
      conn = Plug.Test.init_test_session(conn, user_id: user1.id)
      assert_raise Ecto.InvalidChangesetError, fn ->
        put(conn, Routes.maintainer_path(conn, :update, user1, repo), maintainer: %{id: to_string(maintainer.id), permission: "foobar"})
      end
    end

    test "deletes maintainer", %{conn: conn, users: [user1, user2], repo: repo, maintainer: maintainer} do
      conn = Plug.Test.init_test_session(conn, user_id: user1.id)
      conn = delete(conn, Routes.maintainer_path(conn, :delete, user1, repo), maintainer: %{id: to_string(maintainer.id)})
      assert get_flash(conn, :info) == "Maintainer '#{user2.login}' deleted."
      assert redirected_to(conn) == Routes.maintainer_path(conn, :index, user1, repo)
    end
  end

  #
  # Helpers
  #

  defp create_users(context) do
    users = Stream.repeatedly(fn -> User.create!(factory(:user)) end)
    users = Enum.take(users, 2)
    on_exit fn ->
      File.rmdir(Path.join(Application.fetch_env!(:gitgud, :git_root), hd(users).login))
    end
    Map.put(context, :users, users)
  end

  defp create_repo(context) do
    repo = Repo.create!(factory(:repo, hd(context.users)))
    on_exit fn ->
      File.rm_rf(RepoStorage.workdir(repo))
    end
    Map.put(context, :repo, repo)
  end

  defp create_maintainer(context) do
    maintainer = Maintainer.create!(user_id: List.last(context.users).id, repo_id: context.repo.id)
    context
    |> Map.put(:maintainer, maintainer)
    |> Map.update!(:repo, &DB.preload(&1, :maintainers))
  end
end
