defmodule GitGud.DB.Migrations.AddUsersEmails do
  use Ecto.Migration

  def change do
    create table("emails") do
      add :user_id,     references("users"), on_delete: :delete_all
      add :email,       :string, null: false
      add :verified,    :boolean, null: false, default: false
      timestamps()
    end
    create unique_index("emails", [:email])

    alter table("users") do
      modify :primary_email_id,  references("emails", on_delete: :nilify_all)
      modify :public_email_id,  references("emails", on_delete: :nilify_all)
    end
  end
end
