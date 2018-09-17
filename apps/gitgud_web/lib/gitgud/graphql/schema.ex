defmodule GitGud.GraphQL.Schema do
  @moduledoc """
  GraphQL schema definition.
  """
  use Absinthe.Schema
  use Absinthe.Relay.Schema, :modern

  alias GitGud.GraphQL.Resolvers

  import_types Absinthe.Type.Custom
  import_types GitGud.GraphQL.Types

  query do
    node field do
      resolve &Resolvers.node/2
    end

    field :user, :user do
      arg :username, non_null(:string)
      resolve &Resolvers.user/3
    end

    field :repo, :repo do
      arg :owner, non_null(:string)
      arg :name, non_null(:string)
      resolve &Resolvers.repo/3
    end
  end

  node interface do
    resolve_type &Resolvers.node_type/2
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
