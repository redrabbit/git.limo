defmodule GitGud.GraphQL.Schema do
  @moduledoc """
  GraphQL schema definition.
  """
  use Absinthe.Schema

  alias GitGud.GraphQL.Resolvers

  import_types Absinthe.Type.Custom
  import_types GitGud.GraphQL.Types

  query do
    field :user, :user do
      arg :username, non_null(:string)
      resolve &Resolvers.resolve_user/3
    end
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
