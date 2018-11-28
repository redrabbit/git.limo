defmodule GitGud.DB.Migrations.AddUsersTable do
  use Ecto.Migration

  def change do
    create table("users") do
      add :login,            :string, null: false, size: 24
      add :name,             :string, null: false, size: 80
      add :primary_email_id, :bigint
      add :public_email_id,  :bigint
      add :bio,              :string
      add :url,              :string
      add :location,         :string
      timestamps()
    end

    create unique_index("users", [:login])
  end
end
