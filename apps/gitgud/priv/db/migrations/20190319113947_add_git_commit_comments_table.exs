defmodule GitGud.DB.Migrations.AddGitCommitCommentsTable do
  use Ecto.Migration

  def change do
    create table("git_commit_comments") do
      add :repo_id, references("repositories"), null: false, on_delete: :delete_all
      add :thread_id, references("comment_threads"), null: false, on_delete: :delete_all
      add :oid, :binary, null: false
      add :blob_oid, :binary, null: false
      add :blob_line, :integer, null: false
    end
  end
end
