defmodule GitGud.DB.Migrations.AddRepositoriesTable do
  use Ecto.Migration

  def change do
    create table("repositories") do
      add :owner_id,    references("users")
      add :name,        :string, null: false, size: 80
      add :public,      :boolean, null: false, default: true
      add :description, :string
      timestamps()
    end
    create unique_index("repositories", [:owner_id, :name])
  end
end
