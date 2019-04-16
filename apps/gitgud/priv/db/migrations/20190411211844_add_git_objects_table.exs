defmodule GitGud.DB.Migrations.AddGitObjectsTable do
  use Ecto.Migration

  def change do
    create table("git_objects", primary_key: false) do
      add :repo_id, references("repositories", on_delete: :delete_all), primary_key: true
      add :oid, :binary, primary_key: true
      add :type, :integer, null: false
      add :size, :integer, null: false
      add :data, :binary
    end
  end
end
