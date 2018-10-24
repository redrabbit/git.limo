defmodule GitGud.DB.Migrations.AddUsersEmails do
  use Ecto.Migration

  def change do
    create table("emails") do
      add :user_id,     references("users"), on_delete: :delete_all
      add :email,       :string, null: false
      add :verified,    :boolean, default: false
      timestamps()
    end
    create unique_index("emails", [:email])
  end
end
