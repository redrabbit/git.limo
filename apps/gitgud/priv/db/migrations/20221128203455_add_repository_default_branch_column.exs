defmodule GitGud.DB.Migrations.AddRepositoryDefaultBranchColumn do
  use Ecto.Migration

  def change do
    alter table("repositories") do
      add :default_branch, :string, null: false, default: "main"
    end
  end
end
