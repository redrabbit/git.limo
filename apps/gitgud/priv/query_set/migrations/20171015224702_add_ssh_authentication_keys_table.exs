defmodule GitGud.QuerySet.Migrations.AddSshAuthenticationKeysTable do
  use Ecto.Migration

  def change do
    create table("ssh_authentication_keys") do
      add :user_id, references("users")
      add :key,    :text
      timestamps()
    end
  end
end
