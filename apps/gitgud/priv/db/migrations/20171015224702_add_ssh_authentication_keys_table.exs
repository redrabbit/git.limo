defmodule GitGud.DB.Migrations.AddSshAuthenticationKeysTable do
  use Ecto.Migration

  def change do
    create table("ssh_authentication_keys") do
      add(:user_id, references("users"), on_delete: :delete_all)
      add(:name, :string, size: 80)
      add(:data, :text, null: false)
      add(:fingerprint, :string, null: false, size: 47)
      timestamps()
    end

    create(unique_index("ssh_authentication_keys", [:user_id, :name]))
    create(unique_index("ssh_authentication_keys", [:user_id, :fingerprint]))
  end
end
