defmodule GitGud.GraphQL.SchemaGenerator do
  @moduledoc false

  require GitGud.GraphQL.Schema
  require GitGud.GraphQL.Types

  modules = [GitGud.GraphQL.Schema, GitGud.GraphQL.Types]
  checksum_path = Path.join([:code.priv_dir(:gitgud_web), "graphql", "schema.md5"])
  checksum = Enum.join(Enum.map(modules, &apply(&1, :__info__, [:md5])))
  if !File.exists?(checksum_path) || File.read!(checksum_path) != checksum do
    schema_path = Path.join([:code.priv_dir(:gitgud_web), "graphql", "schema.json"])
    Mix.Tasks.Absinthe.Schema.Json.run([schema_path, "--json-codec", "Jason"])
    File.write!(checksum_path, checksum)
  end
end
