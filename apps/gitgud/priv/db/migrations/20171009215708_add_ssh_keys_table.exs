defmodule GitGud.DB.Migrations.AddSSHKeysTable do
  use Ecto.Migration

  def change do
    create table("ssh_keys") do
      add :user_id,       references("users"), null: false, on_delete: :delete_all
      add :name,          :string, size: 80
      add :fingerprint,   :string, null: false, size: 47
      timestamps(updated_at: false)
      add :last_used_at,  :naive_datetime
    end
    create unique_index("ssh_keys", [:user_id, :name])
    create unique_index("ssh_keys", [:user_id, :fingerprint])
  end
end
