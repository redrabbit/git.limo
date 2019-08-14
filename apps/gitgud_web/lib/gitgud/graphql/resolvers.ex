defmodule GitGud.GraphQL.Resolvers do
  @moduledoc """
  Module providing resolution functions for GraphQL related queries.
  """

  alias GitRekt.GitAgent
  alias GitRekt.{GitCommit, GitRef, GitTag, GitTree, GitBlob}

  alias GitGud.DB
  alias GitGud.DBQueryable

  alias GitGud.User
  alias GitGud.UserQuery
  alias GitGud.Repo
  alias GitGud.RepoQuery
  alias GitGud.Comment
  alias GitGud.CommentQuery
  alias GitGud.CommitLineReview
  alias GitGud.CommitReview
  alias GitGud.ReviewQuery

  alias Absinthe.Relay.Connection

  alias GitGud.Web.Router.Helpers, as: Routes

  import Absinthe.Subscription, only: [publish: 3]
  import Absinthe.Resolution.Helpers, only: [batch: 3]

  import GitRekt.Git, only: [oid_fmt: 1]

  import GitGud.Authorization, only: [authorized?: 3]
  import GitGud.GraphQL.Schema, only: [from_relay_id: 1, from_relay_id: 3]

  @doc """
  Resolves a node object type.
  """
  @spec node_type(map, Absinthe.Resolution.t) :: atom | nil
  def node_type(%User{} = _node, _info), do: :user
  def node_type(%Repo{} = _node, _info), do: :repo
  def node_type(%Comment{} = _node, _info), do: :comment
  def node_type(%CommitLineReview{} = _node, _info), do: :commit_line_review
  def node_type(%CommitReview{} = _node, _info), do: :commit_review
  def node_type(_struct, _info), do: nil

  @doc """
  Resolves a node object.
  """
  @spec node(map, Absinthe.Resolution.t, keyword) :: {:ok, map} | {:error, term}
  def node(node_type, info, opts \\ [])
  def node(%{id: id, type: :user}, info, opts) do
    if user = UserQuery.by_id(String.to_integer(id), preload: Keyword.get(opts, :preload, :public_email)),
      do: {:ok, user},
    else: node(%{id: id}, info)
  end

  def node(%{id: id, type: :repo}, %{context: ctx} = info, opts) do
    if repo = RepoQuery.by_id(String.to_integer(id), viewer: ctx[:current_user], preload: Keyword.get(opts, :preload, [owner: :public_email])),
      do: {:middleware, GitGud.GraphQL.CacheRepoMiddleware, repo},
    else: node(%{id: id}, info)
  end

  def node(%{id: id, type: :comment}, %{context: ctx} = info, opts) do
    if comment = CommentQuery.by_id(id, viewer: ctx[:current_user], preload: Keyword.get(opts, :preload, :author)),
      do: {:ok, comment},
    else: node(%{id: id}, info)
  end

  def node(%{id: id, type: :commit_line_review}, %{context: ctx} = info, opts) do
    if review = ReviewQuery.commit_line_review_by_id(id, viewer: ctx[:current_user], preload: Keyword.get(opts, :preload, [:repo, comments: :author])),
      do: {:ok, review},
    else: node(%{id: id}, info)
  end

  def node(%{id: id, type: :commit_review}, %{context: ctx} = info, opts) do
    if review = ReviewQuery.commit_review_by_id(id, viewer: ctx[:current_user], preload: Keyword.get(opts, :preload, [:repo, comments: :author])),
      do: {:ok, review},
    else: node(%{id: id}, info)
  end

  def node(_node_type, _info, _opts) do
    {:error, "this given node id is not valid"}
  end

  @doc """
  Resolves the URL of the given `resource`.
  """
  @spec url(map, %{}, Absinthe.Resolution.t) :: {:ok, binary} | {:error, term}
  def url(%User{login: login} = _resource, %{} = _args, _info) do
    {:ok, Routes.user_url(GitGud.Web.Endpoint, :show, login)}
  end

  def url(%Repo{} = repo, %{} = _args, _info) do
    {:ok, Routes.codebase_url(GitGud.Web.Endpoint, :show, repo.owner, repo)}
  end

  def url(%GitRef{name: name} = _reference, %{} = _args, %Absinthe.Resolution{context: ctx} = _info) do
    {:ok, Routes.codebase_url(GitGud.Web.Endpoint, :tree, ctx.repo.owner, ctx.repo, name, [])}
  end

  def url(%GitCommit{oid: oid} = _commit, %{} = _args, %Absinthe.Resolution{context: ctx} = _info) do
    {:ok, Routes.codebase_url(GitGud.Web.Endpoint, :commit, ctx.repo.owner, ctx.repo, oid_fmt(oid))}
  end

  @doc """
  Resolves an user object by login.
  """
  @spec user(%{}, %{login: binary}, Absinthe.Resolution.t) :: {:ok, User.t} | {:error, term}
  def user(%{} = _root, %{login: login} = _args, _info) do
    if user = UserQuery.by_login(login, preload: :public_email),
      do: {:ok, user},
    else: {:error, "this given login '#{login}' is not valid"}
  end

  @doc """
  Resolves the public email for a given `user`.
  """
  @spec user_public_email(User.t, %{}, Absinthe.Resolution.t) :: {:ok, GitReference.t} | {:error, term}
  def user_public_email(%User{} = user, %{} = _args, _info) do
    if email = user.public_email,
      do: {:ok, email.address},
    else: {:ok, nil}
  end

  @doc """
  Resolves the HTML content of a given `comment`.
  """
  @spec user_bio_html(User.t, %{}, Absinthe.Resolution.t) :: {:ok, integer} | {:error, term}
  def user_bio_html(user, %{} = _args, _info) do
    markdown(user.bio)
  end

  @doc """
  Resolves a list of users for a given search term.
  """
  @spec search(map, Absinthe.Resolution.t) :: {:ok, Connection.t} | {:error, term}
  def search(%{all: input} = args, %Absinthe.Resolution{context: ctx} = _info) do
    users = UserQuery.search(input, viewer: ctx[:current_user], preload: :public_email)
    repos = RepoQuery.search(input, viewer: ctx[:current_user], preload: [owner: :public_email])
    Connection.from_list(users ++ repos, args)
  end

  def search(%{user: input} = args, %Absinthe.Resolution{context: ctx} = _info) do
    query = DBQueryable.query({UserQuery, :search_query}, input, viewer: ctx[:current_user], preload: :public_email)
    Connection.from_query(query, &DB.all/1, args)
  end

  def search(%{repo: input} = args, %Absinthe.Resolution{context: ctx} = _info) do
    query = DBQueryable.query({RepoQuery, :search_query}, input, viewer: ctx[:current_user], preload: [owner: :public_email])
    Connection.from_query(query, &DB.all/1, args)
  end

  @spec search_result_type(User.t|Repo.t, Absinthe.Resolution.t) :: atom
  def search_result_type(%User{}, _info), do: :user
  def search_result_type(%Repo{}, _info), do: :repo

  @doc """
  Resolves a repository object by name for a given `user`.
  """
  @spec user_repo(User.t, %{name: binary}, Absinthe.Resolution.t) :: {:ok, Repo.t} | {:error, term}
  def user_repo(%User{} = user, %{name: name} = _args, %Absinthe.Resolution{context: ctx} = _info) do
    if repo = RepoQuery.user_repo(user, name, viewer: ctx[:current_user], preload: [owner: :public_email]),
      do: {:middleware, GitGud.GraphQL.CacheRepoMiddleware, repo},
    else: {:error, "this given repository name '#{name}' is not valid"}
  end

  @doc """
  Resolves all repositories for a given `user`.
  """
  @spec user_repos(map, Absinthe.Resolution.t) :: {:ok, Connection.t} | {:error, term}
  def user_repos(args, %Absinthe.Resolution{source: user, context: ctx} = _info) do
    query = DBQueryable.query({RepoQuery, :user_repos_query}, user, viewer: ctx[:current_user], preload: [owner: :public_email])
    Connection.from_query(query, fn query -> Enum.map(DB.all(query), &GitAgent.attach!/1) end, args)
  end

  def repo(%{owner: owner, name: name}, %Absinthe.Resolution{context: ctx} = _info) do
    if repo = RepoQuery.user_repo(owner, name, viewer: ctx[:current_user], preload: [owner: :public_email]),
      do: {:middleware, GitGud.GraphQL.CacheRepoMiddleware, repo},
    else: {:error, "this given repository '#{owner}/#{name}' is not valid"}
  end

  @doc """
  Resolves the owner for a given `repo`.
  """
  @spec repo_owner(Repo.t, %{}, Absinthe.Resolution.t) :: {:ok, User.t} | {:error, term}
  def repo_owner(%Repo{} = repo, %{} = _args, _info) do
    {:ok, repo.owner}
  end

  @doc """
  Resolves the HTML content of a given `comment`.
  """
  @spec repo_description_html(Repo.t, %{}, Absinthe.Resolution.t) :: {:ok, integer} | {:error, term}
  def repo_description_html(repo, %{} = _args, _info) do
    markdown(repo.description)
  end

  @doc """
  Resolves the default branch object for a given `repo`.
  """
  @spec repo_head(Repo.t, %{}, Absinthe.Resolution.t) :: {:ok, GitReference.t} | {:error, term}
  def repo_head(%Repo{} = repo, %{} = _args, _info) do
    GitAgent.head(repo)
  end

  @doc """
  Resolves a Git reference object by name for a given `repo`.
  """
  @spec repo_ref(Repo.t, %{name: binary}, Absinthe.Resolution.t) :: {:ok, GitReference.t} | {:error, term}
  def repo_ref(%Repo{} = repo, %{name: name} = _args, _info) do
    GitAgent.reference(repo, name)
  end

  @doc """
  Resolves all Git reference objects for a given `repo`.
  """
  @spec repo_refs(map, Absinthe.Resolution.t) :: {:ok, Connection.t} | {:error, term}
  def repo_refs(args, %Absinthe.Resolution{source: repo} = _source) do
    case GitAgent.references(repo) do
      {:ok, stream} ->
        {slice, offset, opts} = slice_stream(stream, args)
        Connection.from_slice(slice, offset, opts)
    {:error, reason} ->
      {:error, reason}
    end
  end

  @doc """
  Resolves a Git tag object by name for a given `repo`.
  """
  @spec repo_tag(Repo.t, %{name: binary}, Absinthe.Resolution.t) :: {:ok, GitReference.t | GitTag.t} | {:error, term}
  def repo_tag(%Repo{} = repo, %{name: name} = _args, _info) do
    GitAgent.tag(repo, name)
  end

  @doc """
  Resolves all Git tag objects for a given `repo`.
  """
  @spec repo_tags(map, Absinthe.Resolution.t) :: {:ok, Connection.t} | {:error, term}
  def repo_tags(args, %Absinthe.Resolution{source: repo} = _source) do
    case GitAgent.tags(repo) do
      {:ok, stream} ->
        {slice, offset, opts} = slice_stream(stream, args)
        Connection.from_slice(slice, offset, opts)
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Resolves the type for a given Git `actor`.
  """
  @spec git_actor_type(User.t | map, Absinthe.Resolution.t) :: atom
  def git_actor_type(%User{} = _actor, _info), do: :user
  def git_actor_type(actor, _info) when is_map(actor), do: :unknown_user

  @doc """
  Resolves the type for a given Git `object`.
  """
  @spec git_object_type(Repo.git_object, Absinthe.Resolution.t) :: atom
  def git_object_type(%GitBlob{} = _object, _info), do: :git_blob
  def git_object_type(%GitCommit{} = _object, _info), do: :git_commit
  def git_object_type(%GitTag{} = _object, _info), do: :git_annotated_tag
  def git_object_type(%GitTree{} = _object, _info), do: :git_tree

  @doc """
  Resolves the type for a given Git `tag`.
  """
  @spec git_reference_type(GitReference.t, %{}, Absinthe.Resolution.t) :: {:ok, atom} | {:error, term}
  def git_reference_type(%GitRef{type: type} = _reference, _args, _info), do: {:ok, type}

  @doc """
  Resolves the Git target for the given Git `reference` object.
  """
  @spec git_reference_target(GitReference.t, %{}, Absinthe.Resolution.t) :: {:ok, Repo.git_object} | {:error, term}
  def git_reference_target(reference, %{} = _args, %Absinthe.Resolution{context: ctx} = _info) do
    GitAgent.peel(ctx.repo, reference)
  end

  @doc """
  Resolves the commit history starting from the given Git `revision` object.
  """
  @spec git_history(map, Absinthe.Resolution.t) :: {:ok, Connection.t} | {:error, term}
  def git_history(args, %Absinthe.Resolution{context: ctx, source: revision} = _source) do
    case GitAgent.history(ctx.repo, revision) do
      {:ok, stream} ->
        {slice, offset, opts} = slice_stream(stream, args)
        Connection.from_slice(slice, offset, opts)
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Resolves the parents for a given Git `commit` object.
  """
  @spec git_commit_parents(map, Absinthe.Resolution.t) :: {:ok, Connection.t} | {:error, term}
  def git_commit_parents(args,  %Absinthe.Resolution{context: ctx, source: commit} = _source) do
    case GitAgent.commit_parents(ctx.repo, commit) do
      {:ok, stream} ->
        {slice, offset, opts} = slice_stream(stream, args)
        Connection.from_slice(slice, offset, opts)
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Resolves the author for a given Git `commit` object.
  """
  @spec git_commit_author(GitCommit.t, %{}, Absinthe.Resolution.t) :: {:ok, User.t | map} | {:error, term}
  def git_commit_author(commit, %{} = _args,  %Absinthe.Resolution{context: ctx} = _info) do
    case GitAgent.commit_author(ctx.repo, commit) do
      {:ok, %{email: email} = author} ->
        batch({__MODULE__, :batch_users_by_email, ctx[:current_user]}, email, fn users -> {:ok, users[email] || author} end)
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Resolves the message for a given Git `commit` object.
  """
  @spec git_commit_message(GitCommit.t, %{}, Absinthe.Resolution.t) :: {:ok, binary} | {:error, term}
  def git_commit_message(commit, %{} = _args, %Absinthe.Resolution{context: ctx} = _info) do
    GitAgent.commit_message(ctx.repo, commit)
  end

  @doc """
  Resolves the timestamp for a given Git `commit` object.
  """
  @spec git_commit_timestamp(GitCommit.t, %{}, Absinthe.Resolution.t) :: {:ok, DateTime.t} | {:error, term}
  def git_commit_timestamp(commit, %{} = _args, %Absinthe.Resolution{context: ctx} = _info) do
    GitAgent.commit_timestamp(ctx.repo, commit)
  end

  @doc """
  Resolves the line review for a given Git `commit` object.
  """
  @spec commit_line_review(GitCommit.t, %{}, Absinthe.Resolution.t) :: {:ok, CommitLineReview.t} | {:error, term}
  def commit_line_review(commit, %{blob_oid: blob_oid, hunk: hunk, line: line} = _args,  %Absinthe.Resolution{context: ctx} = _info) do
    if line_review = ReviewQuery.commit_line_review(ctx.repo, commit, blob_oid, hunk, line, viewer: ctx[:current_user], preload: [comments: :author]),
      do: {:ok, line_review},
    else: {:error, "there is no line review for the given args"}
  end

  @doc """
  Resolves the review for a given Git `commit` object.
  """
  @spec commit_review(GitCommit.t, %{}, Absinthe.Resolution.t) :: {:ok, CommitLineReview.t} | {:error, term}
  def commit_review(commit, %{} = _args,  %Absinthe.Resolution{context: ctx} = _info) do
    {:ok, ReviewQuery.commit_review(ctx.repo, commit, viewer: ctx[:current_user], preload: [comments: :author])}
  end

  @doc """
  Resolves the author for a given Git `tag` object.
  """
  @spec git_tag_author(GitTag.t, %{}, Absinthe.Resolution.t) :: {:ok, User.t | map} | {:error, term}
  def git_tag_author(tag, %{} = _args, %Absinthe.Resolution{context: ctx} = _info) do
    case GitAgent.tag_author(ctx.repo, tag) do
      {:ok, %{email: email} = author} ->
         batch({__MODULE__, :batch_users_by_email, ctx[:current_user]}, email, fn users -> {:ok, users[email] || author} end)
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Resolves the message for a given Git `tag` object.
  """
  @spec git_tag_message(GitTag.t, %{}, Absinthe.Resolution.t) :: {:ok, binary} | {:error, term}
  def git_tag_message(tag, %{} = _args, %Absinthe.Resolution{context: ctx} = _info) do
    GitAgent.tag_message(ctx.repo, tag)
  end

  @doc """
  Resolves the Git target for the given Git `tag` object.
  """
  @spec git_tag_target(GitTag.t, %{}, Absinthe.Resolution.t) :: {:ok, Repo.git_object} | {:error, term}
  def git_tag_target(tag, %{} = _args, %Absinthe.Resolution{context: ctx} = _info) do
    GitAgent.peel(ctx.repo, tag)
  end

  @doc """
  Resolves the type for a given Git `tag`.
  """
  @spec git_tag_type(GitReference.t | GitTag.t, Absinthe.Resolution.t) :: {:ok, atom} | {:error, term}
  def git_tag_type(%GitRef{} = _ref, _info), do: :git_reference
  def git_tag_type(%GitTag{} = _tag, _info), do: :git_annotated_tag

  @doc """
  Resolves the tree for a given Git `commit` object.
  """
  @spec git_tree(Repo.git_revision, %{}, Absinthe.Resolution.t) :: {:ok, GitTree.t} | {:error, term}
  def git_tree(revision, %{} = _args, %Absinthe.Resolution{context: ctx} = _info) do
    GitAgent.tree(ctx.repo, revision)
  end

  @doc """
  Resolves the tree entries for a given Git `tree` object.
  """
  @spec git_tree_entries(map, Absinthe.Resolution.t) :: {:ok, Connection.t} | {:error, term}
  def git_tree_entries(args, %Absinthe.Resolution{context: ctx, source: tree} = _source) do
    case GitAgent.tree_entries(ctx.repo, tree) do
      {:ok, stream} ->
        {slice, offset, opts} = slice_stream(stream, args)
        Connection.from_slice(slice, offset, opts)
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Returns the underlying Git object for a given Git `tree_entry` object.
  """
  @spec git_tree_entry_target(Repo.t, %{}, Absinthe.Resolution.t) :: {:ok, GitTree.t | GitBlob.t} | {:error, term}
  def git_tree_entry_target(tree_entry, %{} = _args, %Absinthe.Resolution{context: ctx} = _info) do
    GitAgent.tree_entry_target(ctx.repo, tree_entry)
  end

  @doc """
  Resolves the content length for a given Git `blob` object.
  """
  @spec git_blob_size(GitBlob.t, %{}, Absinthe.Resolution.t) :: {:ok, integer} | {:error, term}
  def git_blob_size(blob, %{} = _args, %Absinthe.Resolution{context: ctx} = _info) do
    GitAgent.blob_size(ctx.repo, blob)
  end

  @doc """
  Returns `true` if the viewer can edit a given `comment`; otherwise, returns `false`.
  """
  @spec comment_editable(Comment.t, %{}, Absinthe.Resolution.t) :: {:ok, boolean} | {:error, term}
  def comment_editable(comment, %{} = _args, %Absinthe.Resolution{context: ctx}) do
     {:ok, authorized?(ctx[:current_user], comment, :admin)}
  end

  @doc """
  Resolves the HTML content of a given `comment`.
  """
  @spec comment_html(Comment.t, %{}, Absinthe.Resolution.t) :: {:ok, integer} | {:error, term}
  def comment_html(comment, %{} = _args, _info) do
    markdown(comment.body)
  end

  @doc """
  Creates a Git commit review.
  """
  @spec create_commit_line_review_comment(any, %{repo_id: pos_integer, commit_oid: Git.oid, blob_oid: Git.oid, hunk: non_neg_integer, line: non_neg_integer, body: binary}, Absinthe.Resolution.t) :: {:ok, Comment.t} | {:error, term}
  def create_commit_line_review_comment(_parent, %{repo_id: repo_id, commit_oid: commit_oid, blob_oid: blob_oid, hunk: hunk, line: line, body: body} = _args, %Absinthe.Resolution{context: ctx}) do
    repo = RepoQuery.by_id(from_relay_id(repo_id), viewer: ctx[:current_user])
    if author = ctx[:current_user] do
      old_line_review = ReviewQuery.commit_line_review(repo, commit_oid, blob_oid, hunk, line)
      case CommitLineReview.add_comment(repo, commit_oid, blob_oid, hunk, line, author, body, with_review: true) do
        {:ok, line_review, comment} ->
          unless old_line_review do
            publish(GitGud.Web.Endpoint, line_review, commit_line_review_create: "#{repo.id}:#{oid_fmt(commit_oid)}:#{oid_fmt(blob_oid)}")
            publish(GitGud.Web.Endpoint, comment, commit_line_review_comment_create: "#{repo.id}:#{oid_fmt(commit_oid)}:#{oid_fmt(blob_oid)}:#{hunk}:#{line}")
          else
            publish(GitGud.Web.Endpoint, comment, commit_line_review_comment_create: "#{repo.id}:#{oid_fmt(commit_oid)}:#{oid_fmt(blob_oid)}:#{hunk}:#{line}")
          end
          {:ok, comment}
        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, "Unauthorized"}
    end
  end

  @spec create_commit_review_comment(any, %{repo_id: pos_integer, commit_oid: Git.oid, body: binary}, Absinthe.Resolution.t) :: {:ok, Comment.t} | {:error, term}
  def create_commit_review_comment(_parent, %{repo_id: repo_id, commit_oid: commit_oid, body: body} = _args, %Absinthe.Resolution{context: ctx}) do
    repo = RepoQuery.by_id(from_relay_id(repo_id), viewer: ctx[:current_user])
    if author = ctx[:current_user] do
      case CommitReview.add_comment(repo, commit_oid, author, body) do
        {:ok, comment} ->
          publish(GitGud.Web.Endpoint, comment, commit_review_comment_create: "#{repo.id}:#{oid_fmt(commit_oid)}")
          {:ok, comment}
        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, "Unauthorized"}
    end
  end

  @doc """
  Updates a comment.
  """
  @spec update_comment(any, %{id: pos_integer, body: binary}, Absinthe.Resolution.t) :: {:ok, Comment.t} | {:error, term}
  def update_comment(_parent, %{id: id, body: body}, %Absinthe.Resolution{context: ctx}) do
    if comment = CommentQuery.by_id(from_relay_id(id), preload: :author) do
      if authorized?(ctx[:current_user], comment, :admin) do
        thread = GitGud.CommentQuery.thread(comment)
        case Comment.update(comment, body: body) do
          {:ok, comment} ->
            publish(GitGud.Web.Endpoint, comment, comment_subscriptions(thread, :update))
            {:ok, comment}
        end
      else
        {:error, "Unauthorized"}
      end
    end
  end


  @doc """
  Updates a comment.
  """
  @spec delete_comment(any, %{id: pos_integer}, Absinthe.Resolution.t) :: {:ok, Comment.t} | {:error, term}
  def delete_comment(_parent, %{id: id}, %Absinthe.Resolution{context: ctx}) do
    if comment = CommentQuery.by_id(from_relay_id(id), preload: :author) do
      if authorized?(ctx[:current_user], comment, :admin) do
        thread = GitGud.CommentQuery.thread(comment)
        case Comment.delete(comment) do
          {:ok, comment} ->
            publish(GitGud.Web.Endpoint, comment, comment_subscriptions(thread, :delete))
            {:ok, comment}
        end
      else
        {:error, "Unauthorized"}
      end
    end
  end

  def commit_line_review_created(%{repo_id: repo_id, commit_oid: commit_oid, blob_oid: blob_oid}, _info) do
     {:ok, topic: "#{from_relay_id(repo_id)}:#{oid_fmt(commit_oid)}:#{oid_fmt(blob_oid)}"}
  end

  def commit_line_review_comment_topic(%{repo_id: repo_id, commit_oid: commit_oid, blob_oid: blob_oid, hunk: hunk, line: line}, _info) do
     {:ok, topic: "#{from_relay_id(repo_id)}:#{oid_fmt(commit_oid)}:#{oid_fmt(blob_oid)}:#{hunk}:#{line}"}
  end

  def commit_review_comment_topic(%{repo_id: repo_id, commit_oid: commit_oid}, _info) do
     {:ok, topic: "#{from_relay_id(repo_id)}:#{oid_fmt(commit_oid)}"}
  end

  def comment_updated(%{id: id}, info), do: {:ok, topic: comment_subscription_topic(id, info)}
  def comment_deleted(%{id: id}, info), do: {:ok, topic: comment_subscription_topic(id, info)}

  @doc false
  @spec batch_users_by_email(any, [binary]) :: map
  def batch_users_by_email(viewer, emails) do
    emails
    |> Enum.uniq()
    |> UserQuery.by_email(viewer: viewer, preload: [:public_email, :emails])
    |> Enum.flat_map(&flatten_user_emails/1)
    |> Map.new()
  end

  @doc false
  @spec batch_repos_by_user_ids(User.t | nil, [pos_integer]) :: map
  def batch_repos_by_user_ids(viewer, user_ids) do
    user_ids
    |> Enum.uniq()
    |> RepoQuery.user_repos(viewer: viewer, preload: [owner: :public_email])
    |> Map.new(&{&1.owner_id, &1})
  end

  #
  # Helpers
  #

  defp flatten_user_emails(user) do
    Enum.map(user.emails, &{&1.address, user})
  end

  defp markdown(content) do
    case Earmark.as_html(content || "") do
      {:ok, html, []} ->
        {:ok, html}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp slice_stream(stream, args) do
    stream = Enum.to_list(stream) # TODO
    count = Enum.count(stream)
    {offset, limit} = slice_range(count, args)
    opts = [has_previous_page: offset > 0, has_next_page: count > offset + limit]
    slice = Enum.to_list(Stream.take(Stream.drop(stream, offset), limit))
    {slice, offset, opts}
  end

  defp slice_range(count, args) do
    {:ok, dir, limit} = Connection.limit(args)
    {:ok, offset} = Connection.offset(args)
    case dir do
      :forward -> {offset || 0, limit}
      :backward ->
        end_offset = offset || count
        start_offset = max(end_offset - limit, 0)
        limit = if start_offset == 0, do: end_offset, else: limit
        {start_offset, limit}
    end
  end

  defp comment_subscription(%CommitLineReview{} = thread, action), do: {String.to_atom("commit_line_review_comment_#{action}"), comment_subscription_topic(thread)}
  defp comment_subscription(%CommitReview{} = thread, action), do: {String.to_atom("commit_review_comment_#{action}"), comment_subscription_topic(thread)}

  defp comment_subscriptions(thread, action), do: [{String.to_atom("comment_#{action}"), comment_subscription_topic(thread)}, comment_subscription(thread, action)]

  defp comment_subscription_topic(%Comment{id: id}), do: id
  defp comment_subscription_topic(%CommitLineReview{repo_id: repo_id, commit_oid: commit_oid, blob_oid: blob_oid, hunk: hunk, line: line}), do: "#{repo_id}:#{oid_fmt(commit_oid)}:#{oid_fmt(blob_oid)}:#{hunk}:#{line}"
  defp comment_subscription_topic(%CommitReview{repo_id: repo_id, commit_oid: commit_oid}), do: "#{repo_id}:#{oid_fmt(commit_oid)}"
  defp comment_subscription_topic(node_id, info), do: comment_subscription_topic(from_relay_id(node_id, info, preload: []))
end
