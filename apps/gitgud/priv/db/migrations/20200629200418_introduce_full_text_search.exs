defmodule :"Elixir.GitGud.DB.Migrations.IntroduceFullTextSearch" do
  use Ecto.Migration

  def up do
    execute("CREATE EXTENSION pg_trgm")
    execute("CREATE INDEX users_login_trgm_index ON users USING GIN (login gin_trgm_ops)")
    execute("CREATE INDEX repositories_name_trgm_index ON repositories USING GIN (name gin_trgm_ops)")
  end

  def down do
    execute("DROP INDEX repositories_name_trgm_index")
    execute("DROP INDEX users_login_trgm_index")
    execute("DROP EXTENSION pg_trgm")
  end
end
