defmodule GitGud.Repo.Migrations.AddRepositoriesTable do
  use Ecto.Migration

  def change do
    create table("repositories") do
      add :owner_id,    references("users")
      add :path,        :string, null: false
      add :name,        :string, null: false, size: 80
      add :description, :string
      timestamps()
    end

    create unique_index("repositories", [:path])
  end
end
