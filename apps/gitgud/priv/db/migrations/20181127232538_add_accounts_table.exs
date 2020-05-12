defmodule GitGud.DB.Migrations.AddAccountsTable do
  use Ecto.Migration

  def change do
    create table("accounts") do
      add :user_id, references("users", on_delete: :delete_all), null: false
      add :password_hash, :string, size: 98
      timestamps()
    end
  end
end
