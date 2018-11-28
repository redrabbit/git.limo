defmodule GitGud.DB.Migrations.AddUsersAuthenticationsProvidersTable do
  use Ecto.Migration

  def change do
    create table("users_authentications_providers") do
      add :auth_id, references("users_authentications"), null: false, on_delete: :delete_all
      add :provider, :string
      add :provider_id, :bigint
      add :token, :string
      timestamps()
    end
    create unique_index("users_authentications_providers", [:provider, :provider_id])
  end
end
