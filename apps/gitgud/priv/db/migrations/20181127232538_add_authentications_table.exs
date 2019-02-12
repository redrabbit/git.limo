defmodule GitGud.DB.Migrations.AddAuthenticationsTable do
  use Ecto.Migration

  def change do
    create table("authentications") do
      add :user_id, references("users"), null: false, on_delete: :delete_all
      add :password_hash, :string, size: 96
      timestamps()
    end
  end
end
