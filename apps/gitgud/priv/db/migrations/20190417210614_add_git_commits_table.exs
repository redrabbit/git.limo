defmodule GitGud.DB.Migrations.AddGitCommitsTable do
  use Ecto.Migration

  def change do
    create table("git_commits", primary_key: false) do
      add :repo_id, references("repositories", on_delete: :delete_all), primary_key: true
      add :oid, :binary, primary_key: true
      add :parents, {:array, :binary}, null: false
      add :message, :text
      add :author_name, :string
      add :author_email, :string
      add :gpg_signature, :binary
      add :committed_at, :naive_datetime
    end

    execute """
    CREATE FUNCTION git_commits_dag(_repo_id bigint, _oid bytea) RETURNS table (oid bytea, parents bytea[]) AS $$
    BEGIN
    RETURN QUERY
      WITH RECURSIVE dg AS (
        SELECT c.oid, c.parents FROM git_commits c WHERE c.repo_id = _repo_id AND c.oid = _oid
        UNION
        SELECT c.oid, c.parents FROM git_commits c INNER JOIN dg ON c.oid = ANY(dg.parents) AND c.repo_id = _repo_id
      )
      SELECT c.oid, c.parents FROM dg c;
    END;
    $$ LANGUAGE plpgsql IMMUTABLE;
    """, "DROP FUNCTION git_commit_dag"
  end
end
