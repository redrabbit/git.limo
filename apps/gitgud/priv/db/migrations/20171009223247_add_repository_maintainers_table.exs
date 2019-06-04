defmodule GitGud.DB.Migrations.AddRepositoryMaintainersTable do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE repository_permissions AS ENUM ('read', 'write', 'admin')",
      "DROP TYPE repository_permissions"
    )

    create table("maintainers") do
      add :user_id, references("users", on_delete: :delete_all), null: false
      add :repo_id, references("repositories", on_delete: :delete_all), null: false
      add :permission, :repository_permissions, null: false, default: "read"
      timestamps()
    end
    create unique_index("maintainers", [:user_id, :repo_id])
  end
end
