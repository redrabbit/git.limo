defmodule GitGud.DB.Migrations.AddUsersEmailsTable do
  use Ecto.Migration

  def change do
    create table("users_emails") do
      add :user_id,     references("users"), null: false, on_delete: :delete_all
      add :address,     :string, null: false
      add :verified,    :boolean, null: false, default: false
      timestamps(updated_at: false)
      add :verified_at, :naive_datetime
    end
    create unique_index("users_emails", [:user_id, :address])

    execute """
    CREATE FUNCTION unique_email_check(new_address VARCHAR) RETURNS BOOLEAN AS $$
    BEGIN
      IF NOT EXISTS (SELECT id FROM users_emails WHERE verified = true AND address = new_address) THEN
        return true;
      ELSE
        return false;
      END IF;
    END;
    $$ LANGUAGE plpgsql;
    """, "DROP FUNCTION unique_email_check()"

    create constraint "users_emails", :users_emails_address_constraint, check: "unique_email_check(address)"

    alter table("users") do
      modify :primary_email_id,  references("users_emails", on_delete: :nilify_all)
      modify :public_email_id,  references("users_emails", on_delete: :nilify_all)
    end
  end
end
