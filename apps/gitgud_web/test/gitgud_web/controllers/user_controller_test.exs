defmodule GitGud.Web.UserControllerTest do
  use GitGud.Web.ConnCase, async: true
  use GitGud.Web.DataFactory

  alias GitGud.Email
  alias GitGud.User
  alias GitGud.UserQuery
  alias GitGud.Repo
  alias GitGud.RepoStorage

  test "renders user registration form", %{conn: conn} do
    conn = get(conn, Routes.user_path(conn, :new))
    assert html_response(conn, 200) =~ ~s(<h1 class="title has-text-grey-lighter">Register</h1>)
  end

  test "creates user with valid params", %{conn: conn} do
    user_params = factory(:user)
    conn = post(conn, Routes.user_path(conn, :create), user: user_params)
    user = UserQuery.by_login(user_params.login)
    assert get_flash(conn, :info) == "Welcome #{user.login}."
    assert get_session(conn, :user_id) == user.id
    assert redirected_to(conn) == Routes.user_path(conn, :show, user)
  end

  test "fails to create user with invalid login", %{conn: conn} do
    user_params = factory(:user)
    conn = post(conn, Routes.user_path(conn, :create), user: Map.delete(user_params, :login))
    assert get_flash(conn, :error) == "Something went wrong! Please check error(s) below."
    assert html_response(conn, 400) =~ ~s(<h1 class="title has-text-grey-lighter">Register</h1>)
    conn = post(conn, Routes.user_path(conn, :create), user: Map.update!(user_params, :login, &(&1<>".")))
    assert get_flash(conn, :error) == "Something went wrong! Please check error(s) below."
    assert html_response(conn, 400) =~ ~s(<h1 class="title has-text-grey-lighter">Register</h1>)
    conn = post(conn, Routes.user_path(conn, :create), user: Map.update!(user_params, :login, &binary_part(&1, 0, 2)))
    assert get_flash(conn, :error) == "Something went wrong! Please check error(s) below."
    assert html_response(conn, 400) =~ ~s(<h1 class="title has-text-grey-lighter">Register</h1>)
  end

  test "fails to create user with invalid email", %{conn: conn} do
    user_params = factory(:user)
    conn = post(conn, Routes.user_path(conn, :create), user: Map.delete(user_params, :emails))
    assert get_flash(conn, :error) == "Something went wrong! Please check error(s) below."
    assert html_response(conn, 400) =~ ~s(<h1 class="title has-text-grey-lighter">Register</h1>)
    conn = post(conn, Routes.user_path(conn, :create), user: Map.update!(user_params, :emails, fn emails -> List.update_at(emails, 0, &%{&1|address: &1.address <> ".0"}) end))
    assert get_flash(conn, :error) == "Something went wrong! Please check error(s) below."
    assert html_response(conn, 400) =~ ~s(<h1 class="title has-text-grey-lighter">Register</h1>)
  end

  test "renders password reset form", %{conn: conn} do
    conn = get(conn, Routes.user_path(conn, :reset_password))
    assert html_response(conn, 200) =~ ~s(<h1 class="title has-text-grey-lighter">Reset password</h1>)
  end

  describe "when user exists" do
    setup :create_user

    test "renders profile", %{conn: conn, user: user} do
      conn = get(conn, Routes.user_path(conn, :show, user))
      assert html_response(conn, 200) =~ ~s(<h1 class="title">#{user.login}</h1>)
      assert html_response(conn, 200) =~ ~s(<h2 class="subtitle">#{user.name}</h2>)
      assert html_response(conn, 200) =~ ~s(Nothing to see here.)
    end

    test "renders profile edit form if authenticated", %{conn: conn, user: user} do
      conn = Plug.Test.init_test_session(conn, user_id: user.id)
      conn = get(conn, Routes.user_path(conn, :edit_profile))
      assert html_response(conn, 200) =~ ~s(<h1 class="title">Settings</h1>)
      assert html_response(conn, 200) =~ ~s(<h2 class="subtitle">Profile</h2>)
    end

    test "fails to render profile edit form if not authenticated", %{conn: conn} do
      conn = get(conn, Routes.user_path(conn, :edit_profile))
      assert html_response(conn, 401) =~ "Unauthorized"
    end

    test "updates profile with valid params", %{conn: conn, user: user} do
      conn = Plug.Test.init_test_session(conn, user_id: user.id)
      conn = put(conn, Routes.user_path(conn, :update_profile), profile: %{name: "Alice", bio: "I love programming!", public_email_id: hd(user.emails).id, website_url: "http://www.example.com"})
      user = UserQuery.by_id(user.id, preload: :emails)
      assert user.name == "Alice"
      assert user.bio == "I love programming!"
      assert user.public_email_id == hd(user.emails).id
      assert user.website_url == "http://www.example.com"
      assert get_flash(conn, :info) == "Profile updated."
      assert redirected_to(conn) == Routes.user_path(conn, :edit_profile)
    end

    test "fails to update profile with invalid public email", %{conn: conn, user: user} do
      conn = Plug.Test.init_test_session(conn, user_id: user.id)
      conn = put(conn, Routes.user_path(conn, :update_profile), profile: %{public_email_id: 0})
      assert get_flash(conn, :error) == "Something went wrong! Please check error(s) below."
      assert html_response(conn, 400) =~ ~s(<h1 class="title">Settings</h1>)
      assert html_response(conn, 400) =~ ~s(<h2 class="subtitle">Profile</h2>)
    end

    test "fails to update profile with invalid url", %{conn: conn, user: user} do
      conn = Plug.Test.init_test_session(conn, user_id: user.id)
      conn = put(conn, Routes.user_path(conn, :update_profile), profile: %{website_url: "http:example.com"})
      assert get_flash(conn, :error) == "Something went wrong! Please check error(s) below."
      assert html_response(conn, 400) =~ ~s(<h1 class="title">Settings</h1>)
      assert html_response(conn, 400) =~ ~s(<h2 class="subtitle">Profile</h2>)
    end

    test "renders password edit form if authenticated", %{conn: conn, user: user} do
      conn = Plug.Test.init_test_session(conn, user_id: user.id)
      conn = get(conn, Routes.user_path(conn, :edit_password))
      assert html_response(conn, 200) =~ ~s(<h1 class="title">Settings</h1>)
      assert html_response(conn, 200) =~ ~s(<h2 class="subtitle">Password</h2>)
    end

    test "fails to render password edit form if not authenticated", %{conn: conn} do
      conn = get(conn, Routes.user_path(conn, :edit_password))
      assert html_response(conn, 401) =~ "Unauthorized"
    end

    test "updates password with valid params", %{conn: conn, user: user} do
      conn = Plug.Test.init_test_session(conn, user_id: user.id)
      conn = put(conn, Routes.user_path(conn, :update_password), auth: %{old_password: "qwertz", password: "qwerty"})
      assert get_flash(conn, :info) == "Password updated."
      assert redirected_to(conn) == Routes.user_path(conn, :edit_password)
    end

    test "fails to update password with invalid old password", %{conn: conn, user: user} do
      conn = Plug.Test.init_test_session(conn, user_id: user.id)
      conn = put(conn, Routes.user_path(conn, :update_password), auth: %{old_password: "qwerty", password: "qwerty"})
      assert get_flash(conn, :error) == "Something went wrong! Please check error(s) below."
      assert html_response(conn, 400) =~ ~s(<h1 class="title">Settings</h1>)
      assert html_response(conn, 400) =~ ~s(<h2 class="subtitle">Password</h2>)
    end

    test "resets password with valid reset token", %{conn: conn, user: user} do
      email_address = hd(user.emails).address
      conn = post(conn, Routes.user_path(conn, :reset_password), email: %{address: email_address})
      assert get_flash(conn, :info) == "A password reset email has been sent to '#{email_address}'."
      assert redirected_to(conn) == Routes.session_path(conn, :new)
      receive do
        {:delivered_email, %Bamboo.Email{text_body: text, to: [{_name, ^email_address}]}} ->
          {start_link, _} = :binary.match(text, "http://")
          conn = get(conn, binary_part(text, start_link, byte_size(text) - start_link))
          assert get_flash(conn, :info) == "Please set a new password below."
          assert html_response(conn, 200) =~ ~s(<h1 class="title">Settings</h1>)
          assert html_response(conn, 200) =~ ~s(<h2 class="subtitle">Password</h2>)
      after
        1_000 -> raise "email not delivered"
      end
    end

    test "fails to reset password with invalid reset token", %{conn: conn, user: user} do
      conn = Plug.Test.init_test_session(conn, user_id: user.id)
      conn = get(conn, Routes.user_path(conn, :verify_password_reset, "abcdefg"))
      assert get_flash(conn, :error) == "Invalid password reset token."
      assert redirected_to(conn) == Routes.session_path(conn, :new)
    end
  end

  describe "when user exists and has repositories" do
    setup [:create_user, :create_repos]

    test "renders user profile", %{conn: conn, user: user, repos: repos} do
      conn = get(conn, Routes.user_path(conn, :show, user))
      assert html_response(conn, 200) =~ ~s(<h1 class="title">#{user.login}</h1>)
      assert html_response(conn, 200) =~ ~s(<h2 class="subtitle">#{user.name}</h2>)
      for repo <- repos do
        assert html_response(conn, 200) =~ ~s(<a class="card-header-title" href="#{Routes.codebase_path(conn, :show, user, repo)}">#{repo.name}</a>)
      end
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
    Map.put(context, :user, struct(user, emails: Enum.map(user.emails, &Email.verify!/1)))
  end

  defp create_repos(context) do
    repos = Enum.take(Stream.repeatedly(fn -> Repo.create!(factory(:repo, context.user)) end), 3)
    on_exit fn ->
      for repo <- repos do
        File.rm_rf(RepoStorage.workdir(repo))
      end
    end
    Map.put(context, :repos, repos)
  end
end
