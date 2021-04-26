defmodule GitGud.DB.Migrations.AddStatsTable do
  use Ecto.Migration

  def change do
    create table("stats") do
      add :repo_id, references("repositories", on_delete: :delete_all)
      add :refs, :map
      timestamps()
    end
  end
end
