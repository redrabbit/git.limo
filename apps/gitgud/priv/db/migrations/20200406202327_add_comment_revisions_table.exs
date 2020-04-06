defmodule GitGud.DB.Migrations.AddCommentRevisionsTable do
  use Ecto.Migration

  def change do
    create table("comment_revisions") do
      add :comment_id, references("comments", on_delete: :delete_all), null: false
      add :author_id, references("users", on_delete: :delete_all), null: false
      add :body, :string, null: false
      timestamps(updated_at: false)
    end
  end
end
