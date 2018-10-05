defmodule GitGud.DB.Migrations.AddRepositoriesPermissions do
  use Ecto.Migration

  def change do
    create table("repositories_maintainers", primary_key: false) do
      add(:repo_id, references("repositories"), on_delete: :delete_all)
      add(:user_id, references("users"), on_delete: :delete_all)
    end

    create(unique_index("repositories_maintainers", [:repo_id, :user_id]))
  end
end
