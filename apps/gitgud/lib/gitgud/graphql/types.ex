defmodule GitGud.GraphQL.Types do
  @moduledoc """
  GraphQL types for `GitGud.GraphQL.Schema`.
  """

  use Absinthe.Schema.Notation

  alias GitRekt.Git
  alias GitGud.GraphQL.Resolvers

  import Absinthe.Resolution.Helpers

  scalar :git_oid, name: "GitObjectID" do
    serialize &Git.oid_fmt/1
    parse &Git.oid_parse/1
  end

  object :user do
    field :username, non_null(:string)
    field :name, :string
    field :email, non_null(:string)
    field :repositories, non_null(list_of(:repository)), resolve: dataloader(Resolvers)
    field :repository, :repository do
      arg :name, non_null(:string)
      resolve &Resolvers.resolve_user_repo/3
    end
  end

  object :repository do
    field :name, non_null(:string)
    field :description, :string
    field :owner, non_null(:user), resolve: dataloader(Resolvers)
    field :head, :git_reference, resolve: &Resolvers.resolve_repo_head/3
    field :object, :git_object do
      arg :revision, non_null(:string)
      resolve &Resolvers.resolve_git_object/3
    end
    field :reference, :git_reference do
      arg :name, :string
      arg :dwim, :string
      resolve &Resolvers.resolve_repo_ref/3
    end
  end

  object :git_reference do
    field :name, non_null(:string)
    field :shorthand, non_null(:string)
    field :object, non_null(:git_object), resolve: &Resolvers.resolve_git_object/3
    field :repository, non_null(:repository), resolve: &Resolvers.resolve_git_repo/3
  end

  interface :git_object do
    field :oid, non_null(:git_oid)
    field :repository, non_null(:repository)
    resolve_type &Resolvers.resolve_git_object_type/2
  end

  object :git_commit do
    interface :git_object
    field :oid, non_null(:git_oid)
    field :author, non_null(:user), resolve: &Resolvers.resolve_git_commit_author/3
    field :message, non_null(:string), resolve: &Resolvers.resolve_git_commit_message/3
    field :tree, non_null(:git_tree), resolve: &Resolvers.resolve_git_commit_tree/3
    field :repository, non_null(:repository), resolve: &Resolvers.resolve_git_repo/3
  end

  object :git_tree do
    interface :git_object
    field :oid, non_null(:git_oid)
    field :count, non_null(:integer), resolve: &Resolvers.resolve_git_tree_count/3
    field :entries, non_null(list_of(:git_tree_entry)), resolve: &Resolvers.resolve_git_tree_entries/3
    field :repository, non_null(:repository), resolve: &Resolvers.resolve_git_repo/3
  end

  object :git_tree_entry do
    field :name, non_null(:string)
    field :type, non_null(:string)
    field :mode, non_null(:integer)
    field :object, non_null(:git_object), resolve: &Resolvers.resolve_git_object/3
    field :repository, non_null(:repository), resolve: &Resolvers.resolve_git_repo/3
  end

  object :git_blob do
    interface :git_object
    field :oid, non_null(:git_oid)
    field :size, non_null(:integer), resolve: &Resolvers.resolve_git_blob_size/3
    field :repository, non_null(:repository), resolve: &Resolvers.resolve_git_repo/3
  end
end
