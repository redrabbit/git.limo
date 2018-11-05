defmodule GitGud.EmailTest do
  use GitGud.DataCase, async: true
  use GitGud.DataFactory

  alias GitGud.User
  alias GitGud.Email

  setup :create_user

  test "creates a new email with valid params", %{user: user} do
    assert {:ok, email} = Email.create(factory(:email, user))
  end

  test "fails to create a new email with invalid email address", %{user: user} do
    params = factory(:email, user)
    assert {:error, changeset} = Email.create(Map.delete(params, :email))
    assert "can't be blank" in errors_on(changeset).email
    assert {:error, changeset} = Email.create(Map.update!(params, :email, &(&1 <> ".0")))
    assert "has invalid format" in errors_on(changeset).email
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
    Map.put(context, :email, Email.create!(factory(:email, context.user)))
  end
end

