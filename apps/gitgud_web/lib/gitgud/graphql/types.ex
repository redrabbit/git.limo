defmodule GitGud.GraphQL.Types do
  @moduledoc """
  GraphQL types for `GitGud.GraphQL.Schema`.
  """

  use Absinthe.Schema.Notation
  use Absinthe.Relay.Schema.Notation, :modern

  alias GitRekt.Git
  alias GitGud.GraphQL.Resolvers

  scalar :git_oid, name: "GitObjectID" do
    serialize &Git.oid_fmt/1
    parse &Git.oid_parse/1
  end

  enum :git_reference_type do
    value :branch
    value :tag
  end

  connection node_type: :user
  connection node_type: :repo
  connection node_type: :git_commit
  connection node_type: :git_reference
  connection node_type: :git_tag
  connection node_type: :git_tree_entry

  interface :git_actor do
    field :name, :string
    field :email, :string
    resolve_type &Resolvers.git_actor_type/2
  end

  interface :git_object do
    field :oid, non_null(:git_oid)
    field :repo, non_null(:repo)
    resolve_type &Resolvers.git_object_type/2
  end

  interface :git_tag do
    field :oid, non_null(:git_oid)
    field :name, non_null(:string)
    field :target, non_null(:git_object), resolve: &Resolvers.git_tag_target/3
    field :repo, non_null(:repo)
    resolve_type &Resolvers.git_tag_type/2
  end

  node object :user do
    interface :git_actor
    field :username, non_null(:string)
    field :name, :string
    field :email, :string, resolve: &Resolvers.user_public_email/3
    connection field :repos, node_type: :repo do
      resolve &Resolvers.user_repos/2
    end
    field :repo, :repo do
      arg :name, non_null(:string)
      resolve &Resolvers.user_repo/3
    end
    field :url, non_null(:string), resolve: &Resolvers.url/3
  end

  object :unknown_user do
    interface :git_actor
    field :name, :string
    field :email, :string
  end

  node object :repo do
    field :name, non_null(:string)
    field :description, :string
    field :owner, non_null(:user), resolve: &Resolvers.repo_owner/3
    field :head, :git_reference, resolve: &Resolvers.repo_head/3
    connection field :refs, node_type: :git_reference do
      arg :glob, :string
      resolve &Resolvers.repo_refs/2
    end
    field :ref, :git_reference do
      arg :name, :string
      resolve &Resolvers.repo_ref/3
    end
    connection field :tags, node_type: :git_tag do
      resolve &Resolvers.repo_tags/2
    end
    field :tag, :git_tag do
      arg :name, :string
      resolve &Resolvers.repo_tag/3
    end
    field :url, non_null(:string), resolve: &Resolvers.url/3
  end

  object :git_reference do
    interface :git_tag
    field :oid, non_null(:git_oid)
    field :prefix, non_null(:string)
    field :name, non_null(:string)
    field :type, non_null(:git_reference_type), resolve: &Resolvers.git_reference_type/3
    field :target, non_null(:git_object), resolve: &Resolvers.git_reference_target/3
    connection field :history, node_type: :git_commit do
      resolve &Resolvers.git_history/2
    end
    field :tree, non_null(:git_tree), resolve: &Resolvers.git_tree/3
    field :repo, non_null(:repo)
    field :url, non_null(:string), resolve: &Resolvers.url/3
  end

  object :git_commit do
    interface :git_object
    field :oid, non_null(:git_oid)
    field :author, non_null(:git_actor), resolve: &Resolvers.git_commit_author/3
    field :message, non_null(:string), resolve: &Resolvers.git_commit_message/3
    field :timestamp, non_null(:datetime), resolve: &Resolvers.git_commit_timestamp/3
    connection field :history, node_type: :git_commit do
      resolve &Resolvers.git_history/2
    end
    field :tree, non_null(:git_tree), resolve: &Resolvers.git_tree/3
    field :repo, non_null(:repo)
    field :url, non_null(:string), resolve: &Resolvers.url/3
  end

  object :git_annotated_tag do
    interface :git_tag
    interface :git_object
    field :oid, non_null(:git_oid)
    field :name, non_null(:string)
    field :author, non_null(:git_actor), resolve: &Resolvers.git_tag_author/3
    field :message, non_null(:string), resolve: &Resolvers.git_tag_message/3
    field :target, non_null(:git_object), resolve: &Resolvers.git_tag_target/3
    connection field :history, node_type: :git_commit do
      resolve &Resolvers.git_history/2
    end
    field :tree, non_null(:git_tree), resolve: &Resolvers.git_tree/3
    field :repo, non_null(:repo)
  end

  object :git_tree do
    interface :git_object
    field :oid, non_null(:git_oid)
    connection field :entries, node_type: :git_tree_entry do
      resolve &Resolvers.git_tree_entries/2
    end
    field :repo, non_null(:repo)
  end

  object :git_tree_entry do
    field :name, non_null(:string)
    field :type, non_null(:string)
    field :mode, non_null(:integer)
    field :target, non_null(:git_object), resolve: &Resolvers.git_tree_entry_target/3
    field :repo, non_null(:repo)
  end

  object :git_blob do
    interface :git_object
    field :oid, non_null(:git_oid)
    field :size, non_null(:integer), resolve: &Resolvers.git_blob_size/3
    field :repo, non_null(:repo)
  end
end
