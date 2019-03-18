defmodule GitGud.DB.Migrations.AddCommentThreadsTable do
  use Ecto.Migration

  def change do
    create table("comment_threads") do
      add :user_id, references("users"), null: false, on_delete: :delete_all
      add :locked, :boolean, null: false, default: false
      timestamps()
    end
  end
end
