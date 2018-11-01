defmodule GitGud.DB.Migrations.AddUsersTable do
  use Ecto.Migration

  def change do
    create table("users") do
      add :username,         :string, null: false, size: 24
      add :name,             :string, size: 80
      add :primary_email_id, :bigint
      add :public_email_id,  :bigint
      add :bio,              :string
      add :url,              :string
      add :location,         :string
      add :password_hash,    :string, null: false
      timestamps()
    end

    create unique_index("users", [:username])
  end
end
