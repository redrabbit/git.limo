defmodule GitGud.DB.Migrations.AddAuthenticationsProvidersTable do
  use Ecto.Migration

  def change do
    create table("authentications_providers") do
      add :auth_id, references("authentications"), null: false, on_delete: :delete_all
      add :provider, :string
      add :provider_id, :bigint
      add :token, :string
      timestamps()
    end
    create unique_index("authentications_providers", [:provider, :provider_id])
  end
end
