defmodule GitGud.DB.Migrations.AddGitReferencesTable do
  use Ecto.Migration

  def change do
    create table("git_references", primary_key: false) do
      add :repo_id, references("repositories", on_delete: :delete_all), primary_key: true
      add :name, :string, primary_key: true
      add :symlink, :string
      add :oid, :binary
    end
  end
end
