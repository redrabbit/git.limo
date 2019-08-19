defmodule GitGud.GraphQL.Types do
  @moduledoc """
  GraphQL types for `GitGud.GraphQL.Schema`.
  """

  use Absinthe.Schema.Notation
  use Absinthe.Relay.Schema.Notation, :modern

  alias GitRekt.Git
  alias GitGud.GraphQL.Resolvers

  @desc "The `GitObjectID` scalar type represents a Git object SHA hash identifier."
  scalar :git_oid, name: "GitObjectID" do
    parse &{:ok, Git.oid_parse(&1.value)}
    serialize &Git.oid_fmt/1
  end

  @desc "The `GitReferenceType` enum represents the type of a Git reference."
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
  connection node_type: :git_tree_entry_commit
  connection node_type: :search_result

  @desc "Represents an actor in a Git commit (ie. an author or committer)."
  interface :git_actor do
    @desc "The name of the Git actor."
    field :name, non_null(:string)

    @desc "The email of the Git actor."
    field :email, :string

    resolve_type &Resolvers.git_actor_type/2
  end

  @desc "Represents a Git object."
  interface :git_object do
    @desc "The Git object ID."
    field :oid, non_null(:git_oid)

    resolve_type &Resolvers.git_object_type/2
  end

  @desc "Represents a Git tag."
  interface :git_tag do
    @desc "The Git object ID."
    field :oid, non_null(:git_oid)

    @desc "The Git tag name."
    field :name, non_null(:string)

    @desc "The Git object the tag points to."
    field :target, non_null(:git_object), resolve: &Resolvers.git_tag_target/3

    resolve_type &Resolvers.git_tag_type/2
  end

  union :search_result do
    types [:user, :repo]

    resolve_type &Resolvers.search_result_type/2
  end

  @desc """
  A user is an individual's account that owns repositories and can make new content.
  """
  node object :user do
    interface :git_actor

    @desc "The login of the user."
    field :login, non_null(:string)

    @desc "The full name of the user."
    field :name, non_null(:string)

    @desc "The public email of the user."
    field :email, :string, resolve: &Resolvers.user_public_email/3

    @desc "The bio email of the user."
    field :bio, :string

    @desc "The bio email of the user."
    field :bio, :string

    @desc "The HTML formatted bio email of the user."
    field :bio_html, :string, resolve: &Resolvers.user_bio_html/3

    @desc "The location of the user."
    field :location, :string

    @desc "The website URL of the user."
    field :website_url, :string

    @desc "The URL of the user's avatar."
    field :avatar_url, :string

    @desc "A list of repositories that the user owns."
    connection field :repos, node_type: :repo do
      resolve &Resolvers.user_repos/2
    end

    @desc "Fetches a user's repository by its name."
    field :repo, :repo do
      arg :name, non_null(:string), description: "The name of the repository."
      resolve &Resolvers.user_repo/3
    end

    @desc "The HTTP URL for this user."
    field :url, non_null(:string), resolve: &Resolvers.url/3
  end

  object :unknown_user do
    interface :git_actor
    field :name, non_null(:string)
    field :email, :string
  end

  @desc "A repository contains the content for a project."
  node object :repo do
    @desc "The name of the repository."
    field :name, non_null(:string)

    @desc "The description of the repository."
    field :description, :string

    @desc "The HTML formatted description of the repository."
    field :description_html, :string, resolve: &Resolvers.repo_description_html/3

    @desc "The owner of the repository."
    field :owner, non_null(:user), resolve: &Resolvers.repo_owner/3

    @desc "The Git HEAD reference for this repository."
    field :head, :git_reference, resolve: &Resolvers.repo_head/3

    @desc "A list of Git references for this repository."
    connection field :refs, node_type: :git_reference do
      arg :glob, :string, description: "Wildcard pattern for reference matching."
      resolve &Resolvers.repo_refs/2
    end

    @desc "Fetches a single Git reference by its name."
    field :ref, :git_reference do
      arg :name, non_null(:string), description: "The name of the reference."
      resolve &Resolvers.repo_ref/3
    end

    @desc "A list of Git tags for this repository."
    connection field :tags, node_type: :git_tag do
      resolve &Resolvers.repo_tags/2
    end

    @desc "Fetches a single Git tag by its name."
    field :tag, :git_tag do
      arg :name, non_null(:string), description: "The name of the tag."
      resolve &Resolvers.repo_tag/3
    end

    @desc "Fetches a single Git object by its OID."
    field :object, non_null(:git_object) do
      arg :oid, non_null(:git_oid), description: "The OID of the object."
      resolve &Resolvers.repo_object/3
    end

    @desc "Fetches a single Git commit by it revision spec"
    field :revision, non_null(:git_commit) do
      arg :spec, non_null(:string), description: "The revision spec."
      resolve &Resolvers.repo_revision/3
    end

    @desc "The HTTP URL for this repository."
    field :url, non_null(:string), resolve: &Resolvers.url/3
  end

  @desc "Represents a Git reference."
  object :git_reference do
    interface :git_tag

    @desc "The Git object ID."
    field :oid, non_null(:git_oid)

    @desc "The reference's prefix, such as `refs/heads/` or `refs/tags/`."
    field :prefix, non_null(:string)

    @desc "The reference's name."
    field :name, non_null(:string)

    @desc "The type of the reference."
    field :type, non_null(:git_reference_type), resolve: &Resolvers.git_reference_type/3

    @desc "The object the reference points to."
    field :target, non_null(:git_object), resolve: &Resolvers.git_reference_target/3

    @desc "The linear commit history starting from this reference."
    connection field :history, node_type: :git_commit do
      resolve &Resolvers.git_history/2
    end

    @desc "The root tree of this reference."
    field :tree, non_null(:git_tree), resolve: &Resolvers.git_tree/3

    @desc "The HTTP URL for this reference."
    field :url, non_null(:string), resolve: &Resolvers.url/3
  end

  @desc "Represents a Git commit."
  object :git_commit do
    interface :git_object

    @desc "The Git object ID."
    field :oid, non_null(:git_oid)

    @desc "The author of the commit."
    field :author, non_null(:git_actor), resolve: &Resolvers.git_commit_author/3

    field :committer, non_null(:git_actor), resolve: &Resolvers.git_commit_committer/3

    @desc "The message of the commit."
    field :message, non_null(:string), resolve: &Resolvers.git_commit_message/3

    @desc "The timestamp of the commit."
    field :timestamp, non_null(:datetime), resolve: &Resolvers.git_commit_timestamp/3

    @desc "The linear commit history starting from this commit."
    connection field :history, node_type: :git_commit do
      resolve &Resolvers.git_history/2
    end

    @desc "The parents of this commit."
    connection field :parents, node_type: :git_commit do
      resolve &Resolvers.git_commit_parents/2
    end

    @desc "The root tree of this commit."
    field :tree, non_null(:git_tree), resolve: &Resolvers.git_tree/3

    connection field :tree_entries_commits, node_type: :git_tree_entry_commit do
      arg :path, :string
      resolve &Resolvers.git_tree_entries_commits/2
    end

    @desc "A single commit line review."
    field :line_review, non_null(:commit_line_review) do
      arg :blob_oid, non_null(:git_oid), description: "The OID of the blob."
      arg :hunk, non_null(:integer), description:  "The delta hunk index."
      arg :line, non_null(:integer), description: "The delta line index."
      resolve &Resolvers.commit_line_review/3
    end

    @desc "All commit line reviews."
    field :line_reviews, list_of(:commit_line_review) do
      resolve &Resolvers.commit_line_reviews/3
    end

    @desc "A single commit review."
    field :review, :commit_review do
      resolve &Resolvers.commit_review/3
    end

    @desc "The HTTP URL for this commit."
    field :url, non_null(:string), resolve: &Resolvers.url/3
  end

  @desc "Represents a Git commit line review."
  node object :commit_line_review do
    @desc "The OID of the commit."
    field :commit_oid, non_null(:git_oid)

    @desc "The OID of the blob."
    field :blob_oid, non_null(:git_oid)

    @desc "The delta hunk index."
    field :hunk, non_null(:integer)

    @desc "The delta line index."
    field :line, non_null(:integer)

    @desc "A list of comments for this review."
    field :comments, list_of(:comment)

    @desc "The repository this commit belongs to."
    field :repo, non_null(:repo)
  end

  @desc "Represents a Git commit review."
  node object :commit_review do
    @desc "The OID of the commit."
    field :commit_oid, non_null(:git_oid)

    @desc "A list of comments for this review."
    field :comments, list_of(:comment)

    @desc "The repository this commit belongs to."
    field :repo, non_null(:repo)
  end

  @desc "Represents a Git annotated tag."
  object :git_annotated_tag do
    interface :git_tag
    interface :git_object

    @desc "The Git object ID."
    field :oid, non_null(:git_oid)

    @desc "The name of this tag."
    field :name, non_null(:string)

    @desc "The author of this tag."
    field :author, non_null(:git_actor), resolve: &Resolvers.git_tag_author/3

    @desc "The message of this tag."
    field :message, non_null(:string), resolve: &Resolvers.git_tag_message/3

    @desc "The object the tag points to."
    field :target, non_null(:git_object), resolve: &Resolvers.git_tag_target/3

    @desc "The linear commit history starting from this tag."
    connection field :history, node_type: :git_commit do
      resolve &Resolvers.git_history/2
    end

    @desc "The root tree of this tag."
    field :tree, non_null(:git_tree), resolve: &Resolvers.git_tree/3
  end

  @desc "Represents a Git tree."
  object :git_tree do
    interface :git_object

    @desc "The Git object ID."
    field :oid, non_null(:git_oid)

    @desc "A list of tree entries."
    connection field :entries, node_type: :git_tree_entry do
      resolve &Resolvers.git_tree_entries/2
    end
  end

  @desc "Represents a Git tree entry."
  object :git_tree_entry do
    @desc "The entry file name."
    field :name, non_null(:string)

    @desc "The entry file type."
    field :type, non_null(:string)

    @desc "The entry file mode."
    field :mode, non_null(:integer)

    @desc "The object the entry points to."
    field :target, non_null(:git_object), resolve: &Resolvers.git_tree_entry_target/3
  end

  object :git_tree_entry_commit do
    field :tree_entry, non_null(:git_tree_entry)
    field :commit, non_null(:git_commit)
  end

  @desc "Represents a Git blob."
  object :git_blob do
    interface :git_object

    @desc "The Git object ID."
    field :oid, non_null(:git_oid)

    @desc "The size in bytes of the blob."
    field :size, non_null(:integer), resolve: &Resolvers.git_blob_size/3
  end

  @desc "Represents a comment."
  node object :comment do
    @desc "The author of the comment."
    field :author, non_null(:user)

    @desc "The body of the comment."
    field :body, non_null(:string)

    @desc "The HTML formatted body of the comment."
    field :body_html, non_null(:string), resolve: &Resolvers.comment_html/3

    @desc "The creation timestamp of the comment."
    field :inserted_at, non_null(:naive_datetime)

    @desc "The last update timestamp of the comment."
    field :updated_at, non_null(:naive_datetime)

    @desc "Returns `true` if the current viewer can edit the comment; otherwise, returns `false`."
    field :editable, non_null(:boolean), resolve: &Resolvers.comment_editable/3
  end
end
