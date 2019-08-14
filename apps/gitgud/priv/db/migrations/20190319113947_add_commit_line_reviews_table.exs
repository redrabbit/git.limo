defmodule GitGud.DB.Migrations.AddCommitLineReviewsTable do
  use Ecto.Migration

  def change do
    create table("commit_line_reviews") do
      add :repo_id, references("repositories", on_delete: :delete_all), null: false
      add :commit_oid, :binary, null: false
      add :blob_oid, :binary, null: false
      add :hunk, :integer, null: false
      add :line, :integer, null: false
      timestamps()
    end

    create unique_index("commit_line_reviews", [:repo_id, :commit_oid, :blob_oid, :hunk, :line])

    create table("commit_line_reviews_comments", primary_key: false) do
      add :thread_id, references("commit_line_reviews", on_delete: :delete_all), null: false
      add :comment_id, references("comments", on_delete: :delete_all), null: false
    end

    execute """
    CREATE FUNCTION cleanup_commit_line_review() RETURNS TRIGGER AS $$
    BEGIN
      IF NOT EXISTS(SELECT TRUE FROM commit_line_reviews_comments WHERE thread_id = OLD.thread_id) THEN
        DELETE FROM commit_line_reviews WHERE id = OLD.thread_id;
      END IF;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """, "DROP FUNCTION cleanup_commit_line_review()"

    execute """
    CREATE TRIGGER commit_line_review_comments_cleanup
      AFTER DELETE ON commit_line_reviews_comments
      FOR EACH ROW
      EXECUTE PROCEDURE cleanup_commit_line_review()
    """, "DROP TRIGGER commit_line_review_comments_cleanup"
  end
end
