defmodule GitGud.DB.Migrations.AddAuthenticationProvidersTable do
  use Ecto.Migration

  def change do
    create table("authentication_providers") do
      add :auth_id, references("authentications"), null: false, on_delete: :delete_all
      add :provider, :string
      add :provider_id, :bigint
      add :token, :string
      timestamps()
    end
    create unique_index("authentication_providers", [:provider, :provider_id])
  end
end
