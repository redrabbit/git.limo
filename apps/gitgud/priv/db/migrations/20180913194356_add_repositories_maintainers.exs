defmodule GitGud.DB.Migrations.AddRepositoriesMaintainers do
  use Ecto.Migration

  def change do
    create table("repositories_maintainers") do
      add :user_id, references("users"), null: false, on_delete: :delete_all
      add :repo_id, references("repositories"), null: false, on_delete: :delete_all
      timestamps()
    end
    create unique_index("repositories_maintainers", [:user_id, :repo_id])
  end
end
