defmodule GitGud.DB.Migrations.AddRepositoriesTable do
  use Ecto.Migration

  def change do
    create table("repositories") do
      add :owner_id, references("users", on_delete: :delete_all), null: false
      add :name, :string, null: false, size: 80
      add :public, :boolean, null: false, default: true
      add :description, :string
      timestamps()
      add :pushed_at, :naive_datetime
    end

    create unique_index("repositories", [:owner_id, :name])

    create table("repositories_contributors", primary_key: false) do
      add :repo_id, references("repositories", on_delete: :delete_all), null: false
      add :user_id, references("users", on_delete: :delete_all), null: false
    end

    create unique_index("repositories_contributors", [:repo_id, :user_id])
  end
end
