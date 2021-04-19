defmodule GitGud.EmailTest do
  use GitGud.DataCase, async: true
  use GitGud.DataFactory

  alias GitGud.User
  alias GitGud.Email

  setup :create_user

  test "creates a new email with valid params", %{user: user} do
    assert {:ok, email} = Email.create(user, factory(:email))
    refute email.verified
  end

  test "fails to create a new email with invalid email address", %{user: user} do
    params = factory(:email)
    assert {:error, changeset} = Email.create(user, Map.delete(params, :address))
    assert "can't be blank" in errors_on(changeset).address
    assert {:error, changeset} = Email.create(user, Map.update!(params, :address, &(&1 <> ".0")))
    assert "has invalid format" in errors_on(changeset).address
  end

  describe "when email exists" do
    setup :create_email

    test "verifies email", %{email: email1} do
      assert {:ok, email2} = Email.verify(email1)
      assert email2.verified
    end

    test "deletes email", %{email: email1} do
      assert {:ok, email2} = Email.delete(email1)
      assert email2.__meta__.state == :deleted
    end
  end

  #
  # Helpers
  #

  defp create_user(context) do
    Map.put(context, :user, User.create!(factory(:user)))
  end

  defp create_email(context) do
    Map.put(context, :email, Email.create!(context.user, factory(:email)))
  end
end
