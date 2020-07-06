defmodule GitGud.DB.Migrations.AddGpgKeysTable do
  use Ecto.Migration

  def change do
    create table("gpg_keys") do
      add :user_id, references("users", on_delete: :delete_all), null: false
      add :key_id, :binary, null: false
      add :sub_keys, {:array, :binary}
      add :emails, {:array, :string}, null: false
      timestamps(updated_at: false)
      add :expires_at, :naive_datetime
    end

    create unique_index("gpg_keys", [:user_id, :key_id])
  end
end
