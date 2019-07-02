defmodule GitGud.DB.Migrations.AddCommitReviewsTable do
  use Ecto.Migration

  def change do
    create table("commit_reviews") do
      add :repo_id, references("repositories", on_delete: :delete_all), null: false
      add :commit_oid, :binary, null: false
      timestamps()
    end

    create unique_index("commit_reviews", [:repo_id, :commit_oid])

    create table("commit_reviews_comments", primary_key: false) do
      add :review_id, references("commit_reviews", on_delete: :delete_all), null: false
      add :comment_id, references("comments", on_delete: :delete_all), null: false
    end

    execute """
    CREATE FUNCTION cleanup_commit_review() RETURNS TRIGGER AS $$
    BEGIN
      IF NOT EXISTS(SELECT TRUE FROM commit_reviews_comments WHERE review_id = OLD.review_id) THEN
        DELETE FROM commit_reviews WHERE id = OLD.review_id;
      END IF;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """, "DROP FUNCTION cleanup_commit_review()"

    execute """
    CREATE TRIGGER commit_review_comments_cleanup
      AFTER DELETE ON commit_reviews_comments
      FOR EACH ROW
      EXECUTE PROCEDURE cleanup_commit_review()
    """, "DROP TRIGGER commit_review_comments_cleanup"
  end
end
