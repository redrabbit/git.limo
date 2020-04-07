defmodule GitGud.Web.EmailControllerTest do
  use GitGud.Web.ConnCase, async: true
  use GitGud.Web.DataFactory

  use Bamboo.Test

  alias GitGud.DB
  alias GitGud.Email
  alias GitGud.User

  setup :create_user

  test "renders email settings if authenticated", %{conn: conn, user: user} do
    conn = Plug.Test.init_test_session(conn, user_id: user.id)
    conn = get(conn, Routes.email_path(conn, :index))
    assert html_response(conn, 200) =~ ~s(<h2 class="subtitle">Emails</h2>)
  end

  test "fails to render email settings if not authenticated", %{conn: conn} do
    conn = get(conn, Routes.email_path(conn, :index))
    assert html_response(conn, 401) =~ "Unauthorized"
  end

  test "creates emails with valid params", %{conn: conn, user: user} do
    email_params = factory(:email)
    conn = Plug.Test.init_test_session(conn, user_id: user.id)
    conn = post(conn, Routes.email_path(conn, :create), email: email_params)
    assert get_flash(conn, :info) == "Email '#{email_params.address}' added."
    assert redirected_to(conn) == Routes.email_path(conn, :index)
    assert_email_delivered_with(subject: "Verify your email address")
  end

  test "fails to create email with invalid email address", %{conn: conn, user: user} do
    email_params = factory(:email)
    conn = Plug.Test.init_test_session(conn, user_id: user.id)
    conn = post(conn, Routes.email_path(conn, :create), email: Map.update!(email_params, :address, &(&1 <> ".0")))
    assert get_flash(conn, :error) == "Something went wrong! Please check error(s) below."
    assert html_response(conn, 400) =~ ~s(<h2 class="subtitle">Emails</h2>)
  end

  test "verifies email with valid verification token", %{conn: conn, user: user} do
    email_params = factory(:email)
    email_address = email_params.address
    conn = Plug.Test.init_test_session(conn, user_id: user.id)
    conn = post(conn, Routes.email_path(conn, :create), email: email_params)
    assert get_flash(conn, :info) == "Email '#{email_address}' added."
    assert redirected_to(conn) == Routes.email_path(conn, :index)
    receive do
      {:delivered_email, %Bamboo.Email{text_body: text, to: [{_name, ^email_address}]}} ->
        [reset_url] = Regex.run(Regex.compile!("#{Regex.escape(GitGud.Web.Endpoint.url)}[^\\s]+"), text)
        conn = get(conn, reset_url)
        assert get_flash(conn, :info) == "Email '#{email_address}' verified."
        assert redirected_to(conn) == Routes.email_path(conn, :index)
    after
      1_000 -> raise "email not delivered"
    end
  end

  test "fails to verify email with invalid verification token", %{conn: conn, user: user} do
    conn = Plug.Test.init_test_session(conn, user_id: user.id)
    conn = get(conn, Routes.email_path(conn, :verify, "abcdefg"))
    assert get_flash(conn, :error) == "Invalid verification token."
    assert html_response(conn, 400) =~ ~s(<h2 class="subtitle">Emails</h2>)
  end

  describe "when emails exist" do
    setup :create_emails

    test "renders emails", %{conn: conn, user: user, emails: emails} do
      conn = Plug.Test.init_test_session(conn, user_id: user.id)
      conn = get(conn, Routes.email_path(conn, :index))
      assert html_response(conn, 200) =~ ~s(<h2 class="subtitle">Emails</h2>)
      for email <- emails do
        assert html_response(conn, 200) =~ email.address
      end
    end

    test "fails to create email with already existing email address", %{conn: conn, user: user, emails: emails} do
      email_params = factory(:email)
      conn = Plug.Test.init_test_session(conn, user_id: user.id)
      conn = post(conn, Routes.email_path(conn, :create), email: Map.put(email_params, :address, hd(emails).address))
      assert get_flash(conn, :error) == "Something went wrong! Please check error(s) below."
      assert html_response(conn, 400) =~ ~s(<h2 class="subtitle">Emails</h2>)
    end

    test "deletes emails", %{conn: conn, user: user, emails: emails} do
      conn = Plug.Test.init_test_session(conn, user_id: user.id)
      for email <- emails do
        conn = delete(conn, Routes.email_path(conn, :delete), email: %{id: to_string(email.id)})
        assert get_flash(conn, :info) == "Email '#{email.address}' deleted."
        assert redirected_to(conn) == Routes.email_path(conn, :index)
      end
    end
  end

  #
  # Helpers
  #

  defp create_user(context) do
    user = User.create!(factory(:user))
    Map.put(context, :user, struct(user, emails: Enum.map(user.emails, &Email.verify!/1)))
  end

  defp create_emails(context) do
    emails = Stream.repeatedly(fn -> Email.create!(factory(:email, context.user)) end)
    context
    |> Map.put(:emails, Enum.take(emails, 2))
    |> Map.update!(:user, &DB.preload(&1, :emails))
  end
end
