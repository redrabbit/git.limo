defmodule GitGud.DB.Migrations.AddCommentsTable do
  use Ecto.Migration

  def change do
    create table("comments") do
      add :thread_id, references("comment_threads"), null: false, on_delete: :delete_all
      add :parent_id, references("comments"), on_delete: :delete_all
      add :user_id, references("users"), null: false, on_delete: :delete_all
      add :body, :string, null: false
      timestamps()
    end
  end
end
