defmodule GitGud.DB.Migrations.AddRepositoryStatsTable do
  use Ecto.Migration

  def change do
    alter table("repositories") do
      add :stats, :map
    end
  end
end
