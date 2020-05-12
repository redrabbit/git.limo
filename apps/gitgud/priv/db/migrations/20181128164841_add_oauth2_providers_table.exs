defmodule GitGud.DB.Migrations.AddOAuth2ProvidersTable do
  use Ecto.Migration

  def change do
    create table("oauth2_providers") do
      add :auth_id, references("accounts", on_delete: :delete_all), null: false
      add :provider, :string
      add :provider_id, :bigint
      add :token, :string
      timestamps()
    end
    create unique_index("oauth2_providers", [:provider, :provider_id])
  end
end
