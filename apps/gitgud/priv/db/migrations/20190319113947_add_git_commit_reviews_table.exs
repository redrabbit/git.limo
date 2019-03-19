defmodule GitGud.DB.Migrations.AddGitCommitReviewTable do
  use Ecto.Migration

  def change do
    create table("git_commit_reviews") do
      add :repo_id, references("repositories"), null: false, on_delete: :delete_all
      add :oid, :binary, null: false
      add :blob_oid, :binary, null: false
      add :hunk, :integer, null: false
      add :line, :integer, null: false
      timestamps()
    end

    create table("git_commit_reviews_comments", primary_key: false) do
      add :review_id, references("git_commit_reviews"), null: false, on_delete: :delete_all
      add :comment_id, references("comments"), null: false, on_delete: :delete_all
    end
  end
end
