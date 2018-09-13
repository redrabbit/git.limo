defmodule GitGud.DB.Migrations.AddRepositoriesPermissions do
  use Ecto.Migration

  def change do
    alter table("repositories") do
      add :public, :boolean, default: true
    end

    create table("repositories_maintainers", primary_key: false) do
      add :repo_id, references("repositories")
      add :user_id, references("users")
    end
    create unique_index("repositories_maintainers", [:repo_id, :user_id])
  end
end
