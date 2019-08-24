defmodule GitGud.DB.Migrations.AddIssuesTable do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE issues_statuses AS ENUM ('open', 'close')",
      "DROP TYPE issues_statuses"
    )

    create table("issues") do
      add :repo_id, references("repositories", on_delete: :delete_all)
      add :number, :integer, null: false, default: 0
      add :title, :string, null: false
      add :status, :issues_statuses, null: false, default: "open"
      add :author_id, references("users", on_delete: :delete_all), null: false
      timestamps()
    end

    create unique_index("issues", [:repo_id, :number])

    create table("issues_comments", primary_key: false) do
      add :thread_id, references("issues", on_delete: :delete_all), null: false
      add :comment_id, references("comments", on_delete: :delete_all), null: false
    end

    execute """
    CREATE FUNCTION issues_number_auto() RETURNS trigger AS $$
    BEGIN
    SELECT COALESCE(MAX(number) + 1, 1)
      INTO NEW.number
      FROM issues
      WHERE repo_id = NEW.repo_id;
    RETURN NEW;
    END;
    $$ LANGUAGE plpgsql STABLE;
    """, "DROP FUNCTION issues_number_auto"

    execute """
    CREATE TRIGGER issues_number_auto
      BEFORE INSERT ON issues
      FOR EACH ROW
      WHEN (NEW.number = 0)
      EXECUTE PROCEDURE issues_number_auto()
    """, "DROP TRIGGER issues_number_auto"
  end
end
