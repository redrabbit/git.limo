defmodule GitGud.DB.Migrations.AddRepositoryMaintainersTable do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE repository_permissions AS ENUM ('read', 'write', 'admin')",
      "DROP TYPE repository_permissions"
    )

    create table("repository_maintainers") do
      add :user_id, references("users"), null: false, on_delete: :delete_all
      add :repo_id, references("repositories"), null: false, on_delete: :delete_all
      add :permission, :repository_permissions, null: false, default: "read"
      timestamps()
    end
    create unique_index("repository_maintainers", [:user_id, :repo_id])
  end
end
