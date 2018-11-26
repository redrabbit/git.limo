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
    create unique_index("users_emails", [:address])

    alter table("users") do
      modify :primary_email_id,  references("users_emails", on_delete: :nilify_all)
      modify :public_email_id,  references("users_emails", on_delete: :nilify_all)
    end
  end
end
