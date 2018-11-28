defmodule GitGud.DB.Migrations.AddUsersAuthenticationsTable do
  use Ecto.Migration

  def change do
    create table("users_authentications") do
      add :user_id, references("users"), null: false, on_delete: :delete_all
      add :password_hash, :string, null: false, size: 96
      timestamps()
    end
  end
end
