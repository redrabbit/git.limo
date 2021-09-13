defmodule GitGud.DB.Migrations.AddRepositoryVolumeColumn do
  use Ecto.Migration

  def change do
    alter table("repositories") do
      add :volume, :string, size: 8
    end
  end
end
