defmodule GitGud.DB.Migrations.AddCommentsTable do
  use Ecto.Migration

  def change do
    create table("comments") do
      add :author_id, references("users", on_delete: :delete_all), null: false
      add :parent_id, references("comments", on_delete: :nilify_all)
      add :body, :string, null: false
      timestamps()
    end
  end
end
