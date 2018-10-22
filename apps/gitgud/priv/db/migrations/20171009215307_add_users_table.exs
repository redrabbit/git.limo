defmodule GitGud.DB.Migrations.AddUsersTable do
  use Ecto.Migration

  def change do
    create table("users") do
      add :username,      :string, null: false, size: 24
      add :name,          :string, size: 80
      add :email,         :string, null: false
      add :password_hash, :string, null: false
      timestamps()
    end

    create unique_index("users", [:username])
    create unique_index("users", [:email])
  end
end
