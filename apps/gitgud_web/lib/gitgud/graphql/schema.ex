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
  @spec from_relay_id(Absinthe.Relay.Node.global_id) :: pos_integer | nil
  def from_relay_id(global_id) do
    case Absinthe.Relay.Node.from_global_id(global_id, GitGud.GraphQL.Schema) do
      {:ok, nil} -> nil
      {:ok, node} -> String.to_integer(node.id)
      {:error, _reason} -> nil
    end
  end

  @doc """
  Returns the Relay global id for the given `schema`.
  """
  @spec to_relay_id(Ecto.Schema.t) :: Absinthe.Relay.Node.global_id | nil
  def to_relay_id(struct) do
    case Ecto.primary_key(struct) do
      [{_, id}] -> to_relay_id(Resolvers.resolve_node_type(struct, nil), id)
    end
  end

  @doc """
  Returns the Relay global id for the given `source_id`.
  """
  @spec to_relay_id(atom | binary, pos_integer) :: Absinthe.Relay.Node.global_id | nil
  def to_relay_id(node_type, source_id) do
    Absinthe.Relay.Node.to_global_id(node_type, source_id, GitGud.GraphQL.Schema)
  end

  query do
    node field do
      resolve &Resolvers.resolve_node/2
    end

    field :user, :user do
      arg :username, non_null(:string)
      resolve &Resolvers.resolve_user/3
    end

    field :repo, :repo do
      arg :owner, non_null(:string)
      arg :name, non_null(:string)
      resolve &Resolvers.resolve_repo/3
    end
  end

  node interface do
    resolve_type &Resolvers.resolve_node_type/2
  end

  #
  # Callbacks
  #

  @impl true
  def context(ctx) do
    loader = Dataloader.add_source(Dataloader.new(), Resolvers, Resolvers.ecto_loader())
    Map.put(ctx, :loader, loader)
  end

  @impl true
  def plugins do
    [Absinthe.Middleware.Dataloader] ++ Absinthe.Plugin.defaults()
  end
end
