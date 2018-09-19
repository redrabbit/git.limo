defmodule GitGud.DB.Migrations.AddSshAuthenticationKeysTable do
  use Ecto.Migration

  def change do
    create table("ssh_authentication_keys") do
      add :user_id, references("users"), on_delete: :delete_all
      add :key,    :text
      timestamps()
    end
  end
end
