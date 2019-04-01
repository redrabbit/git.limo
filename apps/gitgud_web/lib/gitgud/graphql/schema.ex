defmodule GitGud.GraphQL.Schema do
  @moduledoc """
  GraphQL schema definition.
  """
  use Absinthe.Schema
  use Absinthe.Relay.Schema, :modern

  @after_compile __MODULE__

  alias GitGud.GraphQL.Resolvers

  import_types Absinthe.Type.Custom
  import_types GitGud.GraphQL.Types

  @doc """
  Returns the source id for the given Relay `global_id`.
  """
  @spec from_relay_id(Absinthe.Relay.Node.global_id) :: pos_integer | nil
  def from_relay_id(global_id) do
    case Absinthe.Relay.Node.from_global_id(global_id, __MODULE__) do
      {:ok, nil} -> nil
      {:ok, node} -> String.to_integer(node.id)
      {:error, _reason} -> nil
    end
  end

  @doc """
  Returns the Relay global id for the given `node`.
  """
  @spec to_relay_id(struct) :: Absinthe.Relay.Node.global_id | nil
  def to_relay_id(node) do
    case Ecto.primary_key(node) do
      [{_, id}] -> to_relay_id(Resolvers.node_type(node, nil), id)
    end
  end

  @doc """
  Returns the Relay global id for the given `source_id`.
  """
  @spec to_relay_id(atom | binary, pos_integer) :: Absinthe.Relay.Node.global_id | nil
  def to_relay_id(node_type, source_id) do
    Absinthe.Relay.Node.to_global_id(node_type, source_id, __MODULE__)
  end

  @desc """
  The query root of the GraphQL interface.
  """
  query do
    node field do
      resolve &Resolvers.node/2
    end

    @desc """
    Perform a search across resources.
    """
    connection field :search, node_type: :search_result do
      arg :all, :string
      arg :user, :string
      arg :repo, :string
      resolve &Resolvers.search/2
    end

    @desc """
    Fetches a user given its login.
    """
    field :user, :user do
      @desc "The login of the user."
      arg :login, non_null(:string)
      resolve &Resolvers.user/3
    end

    @desc """
    Fetches a repository given its owner and name.
    """
    field :repo, :repo do
      @desc "The login of the user."
      arg :owner, non_null(:string)
      @desc "The name of the repository."
      arg :name, non_null(:string)
      resolve &Resolvers.repo/2
    end
  end

  mutation do
    @desc "Create a comment"
    field :add_git_commit_comment, type: :comment do
      arg :repo, non_null(:id)
      arg :commit, non_null(:git_oid)
      arg :blob, non_null(:git_oid)
      arg :hunk, non_null(:integer)
      arg :line, non_null(:integer)
      arg :body, non_null(:string)
      resolve &Resolvers.create_git_commit_comment/3
    end

    @desc "Delete a comment"
    field :delete_comment, type: :comment do
      arg :comment, non_null(:id)
      resolve &Resolvers.delete_comment/3
    end
  end


  node interface do
    resolve_type &Resolvers.node_type/2
  end

  def __after_compile__(_env, _bytecode) do
    output_path = Path.join([:code.priv_dir(:gitgud_web), "graphql", "schema.json"])
    Mix.Tasks.Absinthe.Schema.Json.run([output_path, "--json-codec", "Jason"])
  end
end
