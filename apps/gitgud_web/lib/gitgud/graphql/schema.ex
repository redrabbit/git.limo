defmodule GitGud.GraphQL.Schema do
  @moduledoc """
  GraphQL schema definition.
  """
  use Absinthe.Schema
  use Absinthe.Relay.Schema, :modern

  alias GitGud.GraphQL.Resolvers

  import_types Absinthe.Type.Custom
  import_types GitGud.GraphQL.Types

  @doc """
  Returns the source id for the given Relay `global_id`.
  """
  @spec from_relay_id(Absinthe.Relay.Node.global_id()) :: pos_integer | nil
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
  @spec to_relay_id(struct) :: Absinthe.Relay.Node.global_id() | nil
  def to_relay_id(node) do
    case Ecto.primary_key(node) do
      [{_, id}] -> to_relay_id(Resolvers.node_type(node, nil), id)
    end
  end

  @doc """
  Returns the Relay global id for the given `source_id`.
  """
  @spec to_relay_id(atom | binary, pos_integer) :: Absinthe.Relay.Node.global_id() | nil
  def to_relay_id(node_type, source_id) do
    Absinthe.Relay.Node.to_global_id(node_type, source_id, __MODULE__)
  end

  query do
    node field do
      resolve &Resolvers.node/2
    end

    field :user, :user do
      arg :username, non_null(:string)
      resolve &Resolvers.user/3
    end

    connection field :user_search, node_type: :user do
      arg :input, non_null(:string)
      resolve &Resolvers.user_search/2
    end
  end

  node interface do
    resolve_type &Resolvers.node_type/2
  end
end
