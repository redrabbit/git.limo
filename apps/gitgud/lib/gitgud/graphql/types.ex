defmodule GitGud.GraphQL.Types do
  use Absinthe.Schema.Notation

  alias GitGud.GraphQL.Resolvers

  import Absinthe.Resolution.Helpers

  object :user do
    field :username, :string
    field :name, :string
    field :email, :string
    field :repositories, non_null(list_of(:repository)), resolve: dataloader(Resolvers)
    field :repository, :repository do
      arg :name, :string
      resolve &Resolvers.resolve_user_repo/3
    end
  end

  object :repository do
    field :name, :string
    field :description, :string
    field :owner, :user, resolve: dataloader(Resolvers)
  end
end
