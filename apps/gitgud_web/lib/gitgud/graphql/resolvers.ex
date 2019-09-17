defmodule GitGud.GraphQL.Resolvers do
  @moduledoc """
  Module providing resolution functions for GraphQL related queries.
  """

  alias GitRekt.GitAgent
  alias GitRekt.{GitCommit, GitRef, GitTag, GitTree, GitBlob}

  alias GitGud.DB
  alias GitGud.DBQueryable

  alias GitGud.Email
  alias GitGud.User
  alias GitGud.UserQuery
  alias GitGud.Repo
  alias GitGud.RepoQuery
  alias GitGud.Comment
  alias GitGud.CommentQuery
  alias GitGud.Issue
  alias GitGud.IssueQuery
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
  def node_type(%Issue{} = _node, _info), do: :issue
  def node_type(%CommitLineReview{} = _node, _info), do: :commit_line_review
  def node_type(%CommitReview{} = _node, _info), do: :commit_review
  def node_type(_struct, _info), do: nil

  @doc """
  Resolves a node object.
  """
  @spec node(map, Absinthe.Resolution.t, keyword) :: {:ok, map} | {:error, term}
  def node(node_type, info, opts \\ [])
  def node(%{id: id, type: :user}, %{context: ctx} = info, opts) do
    if user = UserQuery.by_id(String.to_integer(id), Keyword.merge(opts, viewer: ctx[:current_user])),
      do: {:ok, user},
    else: node(%{id: id}, info)
  end

  def node(%{id: id, type: :repo}, %{context: ctx} = info, opts) do
    if repo = RepoQuery.by_id(String.to_integer(id), Keyword.merge(opts, viewer: ctx[:current_user])),
      do: {:middleware, GitGud.GraphQL.RepoMiddleware, repo},
    else: node(%{id: id}, info)
  end

  def node(%{id: id, type: :comment}, %{context: ctx} = info, opts) do
    if comment = CommentQuery.by_id(String.to_integer(id), Keyword.merge(opts, viewer: ctx[:current_user])),
      do: {:ok, comment},
    else: node(%{id: id}, info)
  end

  def node(%{id: id, type: :issue}, %{context: ctx} = info, opts) do
    if issue = IssueQuery.by_id(String.to_integer(id), Keyword.merge(opts, viewer: ctx[:current_user])),
      do: {:ok, issue},
    else: node(%{id: id}, info)
  end

  def node(%{id: id, type: :commit_line_review}, %{context: ctx} = info, opts) do
    {preload, opts} = Keyword.pop(opts, :preload, :repo)
    if review = ReviewQuery.commit_line_review_by_id(String.to_integer(id), Keyword.merge(opts, viewer: ctx[:current_user], preload: preload)),
      do: {:ok, review},
    else: node(%{id: id}, info)
  end

  def node(%{id: id, type: :commit_review}, %{context: ctx} = info, opts) do
    {preload, opts} = Keyword.pop(opts, :preload, :repo)
    if review = ReviewQuery.commit_review_by_id(String.to_integer(id), Keyword.merge(opts, viewer: ctx[:current_user], preload: preload)),
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
  def user(%{} = _root, %{login: login} = _args, %Absinthe.Resolution{context: ctx} = _info) do
    if user = UserQuery.by_login(login, viewer: ctx[:current_user]),
      do: {:ok, user},
    else: {:error, "this given login '#{login}' is not valid"}
  end

  @doc """
  Resolves the public email for a given `user`.
  """
  @spec user_public_email(User.t, %{}, Absinthe.Resolution.t) :: {:ok, GitReference.t} | {:error, term}
  def user_public_email(%User{public_email_id: email_id} = _user, %{} = _args, %Absinthe.Resolution{context: ctx} = _info) do
    unless is_nil(email_id),
      do: batch({__MODULE__, :batch_emails_by_ids, ctx[:current_user]}, email_id, fn emails -> {:ok, emails[email_id].address} end),
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
    users = UserQuery.search(input, viewer: ctx[:current_user])
    repos = RepoQuery.search(input, viewer: ctx[:current_user])
    Connection.from_list(users ++ repos, args)
  end

  def search(%{user: input} = args, %Absinthe.Resolution{context: ctx} = _info) do
    query = DBQueryable.query({UserQuery, :search_query}, input, viewer: ctx[:current_user])
    Connection.from_query(query, &DB.all/1, args)
  end

  def search(%{repo: input} = args, %Absinthe.Resolution{context: ctx} = _info) do
    query = DBQueryable.query({RepoQuery, :search_query}, input, viewer: ctx[:current_user])
    Connection.from_query(query, &DB.all/1, args)
  end

  @doc """
  Returns the search result type.
  """
  @spec search_result_type(User.t|Repo.t, Absinthe.Resolution.t) :: atom
  def search_result_type(%User{} = _result, _info), do: :user
  def search_result_type(%Repo{} = _result, _info), do: :repo

  @doc """
  Resolves a repository object by name for a given `user`.
  """
  @spec user_repo(User.t, %{name: binary}, Absinthe.Resolution.t) :: {:ok, Repo.t} | {:error, term}
  def user_repo(%User{} = user, %{name: name} = _args, %Absinthe.Resolution{context: ctx} = _info) do
    if repo = RepoQuery.user_repo(user, name, viewer: ctx[:current_user]),
      do: {:middleware, GitGud.GraphQL.RepoMiddleware, repo},
    else: {:error, "this given repository name '#{name}' is not valid"}
  end

  @doc """
  Resolves all repositories for an user.
  """
  @spec user_repos(map, Absinthe.Resolution.t) :: {:ok, Connection.t} | {:error, term}
  def user_repos(args, %Absinthe.Resolution{source: user, context: ctx} = _info) do
    query = DBQueryable.query({RepoQuery, :user_repos_query}, user, viewer: ctx[:current_user])
    Connection.from_query(query, fn query -> Enum.map(DB.all(query), &GitAgent.attach!/1) end, args)
  end

  @doc """
  Resolves a repository object.
  """
  @spec repo(map, Absinthe.Resolution.t) :: {:ok, Repo.t} | {:error, term}
  def repo(%{owner: owner, name: name} = _args, %Absinthe.Resolution{context: ctx} = _info) do
    if repo = RepoQuery.user_repo(owner, name, viewer: ctx[:current_user]),
      do: {:middleware, GitGud.GraphQL.RepoMiddleware, repo},
    else: {:error, "this given repository '#{owner}/#{name}' is not valid"}
  end

  @doc """
  Resolves the HTML content of a given `comment`.
  """
  @spec repo_description_html(Repo.t, %{}, Absinthe.Resolution.t) :: {:ok, integer} | {:error, term}
  def repo_description_html(repo, %{} = _args, _info) do
    markdown(repo.description)
  end

  @doc """
  Resolves issues for a repository.
  """
  @spec repo_issues(map, Absinthe.Resolution.t) :: {:ok, Connection.t} | {:error, term}
  def repo_issues(args, %Absinthe.Resolution{source: repo, context: ctx} = _info) do
    query = DBQueryable.query({IssueQuery, :repo_issues_query}, repo.id, viewer: ctx[:current_user])
    Connection.from_query(query, &DB.all/1, args)
  end

  @doc """
  Resolves a single issue of a given `repo`.
  """
  @spec repo_issue(Repo.t, %{number: number}, Absinthe.Resolution.t) :: {:ok, integer} | {:error, term}
  def repo_issue(repo, %{number: number} = _args, %Absinthe.Resolution{context: ctx} = _info) do
    if issue = IssueQuery.repo_issue(repo, number, viewer: ctx[:current_user]),
      do: {:ok, issue},
    else: {:error, "there is no issue for the given args"}
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
  def repo_refs(args, %Absinthe.Resolution{source: repo} = _info) do
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
  def repo_tags(args, %Absinthe.Resolution{source: repo} = _info) do
    case GitAgent.tags(repo) do
      {:ok, stream} ->
        {slice, offset, opts} = slice_stream(stream, args)
        Connection.from_slice(slice, offset, opts)
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Resolves a Git object by OID for a given `repo`.
  """
  @spec repo_object(Repo.t, %{oid: binary}, Absinthe.Resolution.t) :: {:ok, GitAgent.git_object} | {:error, term}
  def repo_object(%Repo{} = repo, %{oid: oid} = _args, _info) do
    GitAgent.object(repo, oid)
  end

  @doc """
  Resolves a Git commit by revision spec for a given `repo`.
  """
  @spec repo_revision(Repo.t, %{spec: binary}, Absinthe.Resolution.t) :: {:ok, GitAgent.git_object} | {:error, term}
  def repo_revision(%Repo{} = repo, %{spec: spec} = _args, _info) do
    case GitAgent.revision(repo, spec) do
     {:ok, object, _reference} ->
       GitAgent.peel(repo, object, :commit)
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
  @spec git_object_type(GitAgent.git_object, Absinthe.Resolution.t) :: atom
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
  @spec git_reference_target(GitReference.t, %{}, Absinthe.Resolution.t) :: {:ok, GitAgent.git_object} | {:error, term}
  def git_reference_target(reference, %{} = _args, %Absinthe.Resolution{context: ctx} = _info) do
    GitAgent.peel(ctx.repo, reference)
  end

  @doc """
  Resolves the commit history starting from the given Git `revision` object.
  """
  @spec git_history(map, Absinthe.Resolution.t) :: {:ok, Connection.t} | {:error, term}
  def git_history(args, %Absinthe.Resolution{context: ctx, source: revision} = _info) do
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
  def git_commit_parents(args,  %Absinthe.Resolution{context: ctx, source: commit} = _info) do
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
  Resolves the committer for a given Git `commit` object.
  """
  @spec git_commit_committer(GitCommit.t, %{}, Absinthe.Resolution.t) :: {:ok, User.t | map} | {:error, term}
  def git_commit_committer(commit, %{} = _args,  %Absinthe.Resolution{context: ctx} = _info) do
    case GitAgent.commit_committer(ctx.repo, commit) do
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
    if line_review = ReviewQuery.commit_line_review(ctx.repo, commit, blob_oid, hunk, line, viewer: ctx[:current_user]),
      do: {:ok, line_review},
    else: {:error, "there is no line review for the given args"}
  end

  @doc """
  Resolves comments for a commit line review.
  """
  @spec commit_line_review_comments(map, Absinthe.Resolution.t) :: {:ok, Connection.t} | {:error, term}
  def commit_line_review_comments(args, %Absinthe.Resolution{source: commit_line_review, context: ctx} = _info) do
    query = DBQueryable.query({ReviewQuery, :comments_query}, commit_line_review, viewer: ctx[:current_user])
    Connection.from_query(query, &DB.all/1, args)
  end

  @doc """
  Resolves the line reviews for a given Git `commit` object.
  """
  @spec commit_line_reviews(GitCommit.t, %{}, Absinthe.Resolution.t) :: {:ok, [CommitLineReview.t]} | {:error, term}
  def commit_line_reviews(commit, %{} = args,  %Absinthe.Resolution{context: ctx} = _info) do
    query = DBQueryable.query({ReviewQuery, :commit_line_reviews_query}, [ctx.repo.id, commit.oid], viewer: ctx[:current_user])
    Connection.from_query(query, &DB.all/1, args)
  end

  @doc """
  Resolves the review for a given Git `commit` object.
  """
  @spec commit_review(GitCommit.t, %{}, Absinthe.Resolution.t) :: {:ok, CommitLineReview.t} | {:error, term}
  def commit_review(commit, %{} = _args,  %Absinthe.Resolution{context: ctx} = _info) do
    {:ok, ReviewQuery.commit_review(ctx.repo, commit, viewer: ctx[:current_user])}
  end

  @doc """
  Resolves comments for a commit review.
  """
  @spec commit_review_comments(map, Absinthe.Resolution.t) :: {:ok, Connection.t} | {:error, term}
  def commit_review_comments(args, %Absinthe.Resolution{source: commit_review, context: ctx} = _info) do
    query = DBQueryable.query({ReviewQuery, :comments_query}, commit_review, viewer: ctx[:current_user])
    Connection.from_query(query, &DB.all/1, args)
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
  @spec git_tag_target(GitTag.t, %{}, Absinthe.Resolution.t) :: {:ok, GitAgent.git_object} | {:error, term}
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
  def git_tree_entries(args, %Absinthe.Resolution{context: ctx, source: tree} = _info) do
    case GitAgent.tree_entries(ctx.repo, tree) do
      {:ok, stream} ->
        {slice, offset, opts} = slice_stream(stream, args)
        Connection.from_slice(slice, offset, opts)
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Resolves the tree entries and their associated commit for a given pathspec.
  """
  @spec git_tree_entry_with_last_commit(map, Absinthe.Resolution.t) :: {:ok, Connection.t} | {:error, term}
  def git_tree_entry_with_last_commit(%{path: path}, %Absinthe.Resolution{context: ctx, source: revision} = _info) do
    case GitAgent.tree_entry_by_path(ctx.repo, revision, path, with_commit: true) do
      {:ok, tree_entry, commit} ->
        {:ok, %{tree_entry: tree_entry, commit: commit}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Resolves the tree entries and their associated commit for a given pathspec.
  """
  @spec git_tree_entries_with_last_commit(map, Absinthe.Resolution.t) :: {:ok, Connection.t} | {:error, term}
  def git_tree_entries_with_last_commit(args, %Absinthe.Resolution{context: ctx, source: revision} = _info) do
    path = args[:path]
    path = if path == "" || is_nil(path), do: :root, else: path
    case GitAgent.tree_entries_by_path(ctx.repo, revision, path, with_commit: true) do
      {:ok, stream} ->
        {slice, offset, opts} = slice_stream(stream, args)
        Connection.from_slice(Enum.map(slice, fn {tree_entry, commit} -> %{tree_entry: tree_entry, commit: commit} end), offset, opts)
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

  def issue_author(%Issue{author_id: user_id} = _issue, _args, %Absinthe.Resolution{context: ctx} = _info) do
    batch({__MODULE__, :batch_users_by_ids, ctx[:current_user]}, user_id, fn users -> {:ok, users[user_id]} end)
  end

  @doc """
  Returns `true` if the viewer can edit a given `issue`; otherwise, returns `false`.
  """
  @spec issue_editable(Issue.t, %{}, Absinthe.Resolution.t) :: {:ok, boolean} | {:error, term}
  def issue_editable(issue, %{} = _args, %Absinthe.Resolution{context: ctx} = _info) do
    {:ok, authorized?(ctx[:current_user], issue, :admin)}
  end

  @doc """
  Resolves comments for an issue.
  """
  @spec issue_comments(map, Absinthe.Resolution.t) :: {:ok, Connection.t} | {:error, term}
  def issue_comments(args, %Absinthe.Resolution{source: issue, context: ctx} = _info) do
    query = DBQueryable.query({IssueQuery, :comments_query}, issue, viewer: ctx[:current_user])
    Connection.from_query(query, &DB.all/1, args)
  end

  def issue_events(issue, _args, _info) do
    {:ok, Enum.map(issue.events, &Map.new(&1, fn
      {"timestamp", val} -> {:timestamp, NaiveDateTime.from_iso8601!(val)}
      {key, val} when is_binary(key) -> {String.to_atom(key), val}
      {key, val} -> {key, val}
    end))}
  end

  def issue_event_type(%{type: "close"}, _info), do: :issue_close_event
  def issue_event_type(%{type: "reopen"}, _info), do: :issue_reopen_event
  def issue_event_type(%{type: "title_update"}, _info), do: :issue_title_update_event

  def issue_event_user(%{user_id: user_id}, _args, %Absinthe.Resolution{context: ctx} = _info) do
    batch({__MODULE__, :batch_users_by_ids, ctx[:current_user]}, user_id, fn users -> {:ok, users[user_id]} end)
  end

  def issue_repo(issue, _args, %Absinthe.Resolution{context: ctx} = _info) do
    {:ok, RepoQuery.by_id(issue.repo_id, viewer: ctx[:current_user])}
  end


  def comment_author(%Comment{author_id: user_id} = _issue, _args, %Absinthe.Resolution{context: ctx} = _info) do
    batch({__MODULE__, :batch_users_by_ids, ctx[:current_user]}, user_id, fn users -> {:ok, users[user_id]} end)
  end

  @doc """
  Returns `true` if the viewer can edit a given `comment`; otherwise, returns `false`.
  """
  @spec comment_editable(Comment.t, %{}, Absinthe.Resolution.t) :: {:ok, boolean} | {:error, term}
  def comment_editable(comment, %{} = _args, %Absinthe.Resolution{context: ctx} = _info) do
    {:ok, authorized?(ctx[:current_user], comment, :admin)}
  end

  @doc """
  Returns `true` if the viewer can delete a given `comment`; otherwise, returns `false`.
  """
  @spec comment_deletable(Comment.t, %{}, Absinthe.Resolution.t) :: {:ok, boolean} | {:error, term}
  def comment_deletable(comment, %{} = _args, %Absinthe.Resolution{context: ctx} = _info) do
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
  Creates a repository issue comment.
  """
  @spec create_issue_comment(any, %{id: pos_integer, body: binary}, Absinthe.Resolution.t) :: {:ok, Comment.t} | {:error, term}
  def create_issue_comment(_parent, %{id: id, body: body} = _args, %Absinthe.Resolution{context: ctx} = _info) do
    if author = ctx[:current_user] do
      if issue = IssueQuery.by_id(from_relay_id(id), viewer: ctx[:current_user]) do
        case Issue.add_comment(issue, author, body) do
          {:ok, comment} ->
            publish(GitGud.Web.Endpoint, comment, issue_comment_create: issue.id)
            {:ok, comment}
          {:error, reason} ->
            {:error, reason}
        end
      end
    else
      {:error, "Unauthorized"}
    end
  end

  @doc """
  Closes a repository issue.
  """
  @spec close_issue(any, %{id: pos_integer}, Absinthe.Resolution.t) :: {:ok, Issue.t} | {:error, term}
  def close_issue(_parent, %{id: id} = _args, %Absinthe.Resolution{context: ctx} = _info) do
    if issue = IssueQuery.by_id(from_relay_id(id), viewer: ctx[:current_user]) do
      if authorized?(ctx[:current_user], issue, :admin) do
       case Issue.close(issue, user_id: ctx[:current_user].id) do
         {:ok, issue} ->
           publish(GitGud.Web.Endpoint, List.last(issue.events), issue_event: issue.id)
           {:ok, issue}
         {:error, reason} ->
           {:error, reason}
       end
     end || {:error, "Unauthorized"}
    end
  end

  @doc """
  Reopens a repository issue.
  """
  @spec reopen_issue(any, %{id: pos_integer}, Absinthe.Resolution.t) :: {:ok, Issue.t} | {:error, term}
  def reopen_issue(_parent, %{id: id} = _args, %Absinthe.Resolution{context: ctx} = _info) do
    if issue = IssueQuery.by_id(from_relay_id(id), viewer: ctx[:current_user]) do
      if authorized?(ctx[:current_user], issue, :admin) do
        case Issue.reopen(issue, user_id: ctx[:current_user].id) do
          {:ok, issue} ->
            publish(GitGud.Web.Endpoint, List.last(issue.events), issue_event: issue.id)
            {:ok, issue}
          {:error, reason} ->
            {:error, reason}
        end
      end || {:error, "Unauthorized"}
    end
  end

  @doc """
  Updates the title of an issue.
  """
  @spec update_issue_title(any, %{id: pos_integer, title: binary}, Absinthe.Resolution.t) :: {:ok, Issue.t} | {:error, term}
  def update_issue_title(_parent, %{id: id, title: title} = _args, %Absinthe.Resolution{context: ctx} = _info) do
    if issue = IssueQuery.by_id(from_relay_id(id), viewer: ctx[:current_user]) do
      if authorized?(ctx[:current_user], issue, :admin) do
        case Issue.update_title(issue, title, user_id: ctx[:current_user].id) do
          {:ok, issue} ->
            publish(GitGud.Web.Endpoint, List.last(issue.events), issue_event: issue.id)
            {:ok, issue}
          {:error, reason} ->
            {:error, reason}
        end
      end || {:error, "Unauthorized"}
    end
  end

  @doc """
  Creates a Git line commit review comment.
  """
  @spec create_commit_line_review_comment(any, %{repo_id: pos_integer, commit_oid: Git.oid, blob_oid: Git.oid, hunk: non_neg_integer, line: non_neg_integer, body: binary}, Absinthe.Resolution.t) :: {:ok, Comment.t} | {:error, term}
  def create_commit_line_review_comment(_parent, %{repo_id: repo_id, commit_oid: commit_oid, blob_oid: blob_oid, hunk: hunk, line: line, body: body} = _args, %Absinthe.Resolution{context: ctx} = _info) do
    repo = RepoQuery.by_id(from_relay_id(repo_id), viewer: ctx[:current_user])
    if author = ctx[:current_user] do
      old_line_review = ReviewQuery.commit_line_review(repo, commit_oid, blob_oid, hunk, line, viewer: ctx[:current_user])
      case CommitLineReview.add_comment(repo, commit_oid, blob_oid, hunk, line, author, body, with_review: true) do
        {:ok, line_review, comment} ->
          unless old_line_review do
            publish(GitGud.Web.Endpoint, line_review, commit_line_review_create: "#{repo.id}:#{oid_fmt(commit_oid)}")
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

  @doc """
  Creates a Git commit review commit.
  """
  @spec create_commit_review_comment(any, %{repo_id: pos_integer, commit_oid: Git.oid, body: binary}, Absinthe.Resolution.t) :: {:ok, Comment.t} | {:error, term}
  def create_commit_review_comment(_parent, %{repo_id: repo_id, commit_oid: commit_oid, body: body} = _args, %Absinthe.Resolution{context: ctx} = _info) do
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
  def update_comment(_parent, %{id: id, body: body} = _args, %Absinthe.Resolution{context: ctx} = _info) do
    if comment = CommentQuery.by_id(from_relay_id(id), viewer: ctx[:current_user]) do
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
  Deletes a comment.
  """
  @spec delete_comment(any, %{id: pos_integer}, Absinthe.Resolution.t) :: {:ok, Comment.t} | {:error, term}
  def delete_comment(_parent, %{id: id} = _args, %Absinthe.Resolution{context: ctx} = _info) do
    if comment = CommentQuery.by_id(from_relay_id(id), viewer: ctx[:current_user]) do
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

  @doc """
  Returns the subscription topic for issue comment events.
  """
  @spec issue_topic(map, map) :: {:ok, keyword} | {:error, term}
  def issue_topic(%{id: id}, _info) do
    {:ok, topic: from_relay_id(id)}
  end

  @doc """
  Returns the subscription topic for commit line review create event.
  """
  @spec commit_line_review_created(map, map) :: {:ok, keyword} | {:error, term}
  def commit_line_review_created(%{repo_id: repo_id, commit_oid: commit_oid}, _info) do
    {:ok, topic: "#{from_relay_id(repo_id)}:#{oid_fmt(commit_oid)}"}
  end

  @doc """
  Returns the subscription topic for commit line review comment events.
  """
  @spec commit_line_review_comment_topic(map, map) :: {:ok, keyword} | {:error, term}
  def commit_line_review_comment_topic(%{repo_id: repo_id, commit_oid: commit_oid, blob_oid: blob_oid, hunk: hunk, line: line}, _info) do
    {:ok, topic: "#{from_relay_id(repo_id)}:#{oid_fmt(commit_oid)}:#{oid_fmt(blob_oid)}:#{hunk}:#{line}"}
  end

  @doc """
  Returns the subscription topic for commit review comment events.
  """
  @spec commit_review_comment_topic(map, map) :: {:ok, keyword} | {:error, term}
  def commit_review_comment_topic(%{repo_id: repo_id, commit_oid: commit_oid}, _info) do
    {:ok, topic: "#{from_relay_id(repo_id)}:#{oid_fmt(commit_oid)}"}
  end

  @doc """
  Returns the subscription topic for comment update events.
  """
  @spec comment_updated(map, map) :: {:ok, keyword} | {:error, term}
  def comment_updated(%{id: id} = _args, info), do: {:ok, topic: comment_subscription_topic(id, info)}

  @doc """
  Returns the subscription topic for comment delete events.
  """
  @spec comment_deleted(map, map) :: {:ok, keyword} | {:error, term}
  def comment_deleted(%{id: id} = _args, info), do: {:ok, topic: comment_subscription_topic(id, info)}

  @doc false
  @spec batch_users_by_ids(User.t | nil, [pos_integer]) :: map
  def batch_users_by_ids(viewer, user_ids) do
    user_ids
    |> Enum.uniq()
    |> UserQuery.by_id(viewer: viewer)
    |> Map.new(&{&1.id, &1})
  end

  @doc false
  @spec batch_users_by_email(User.t | nil, [binary]) :: map
  def batch_users_by_email(viewer, emails) do
    emails
    |> Enum.uniq()
    |> UserQuery.by_email(viewer: viewer, preload: [:emails])
    |> Enum.flat_map(&flatten_user_emails/1)
    |> Map.new()
  end

  @doc false
  @spec batch_repos_by_user_ids(User.t | nil, [pos_integer]) :: map
  def batch_repos_by_user_ids(viewer, user_ids) do
    user_ids
    |> Enum.uniq()
    |> RepoQuery.user_repos(viewer: viewer)
    |> Map.new(&{&1.owner_id, &1})
  end

  @doc false
  @spec batch_emails_by_ids(User.t | nil, [pos_integer]) :: map
  def batch_emails_by_ids(_viewer, email_ids) do
    import Ecto.Query
    from(e in Email, where: e.id in ^Enum.uniq(email_ids) and e.verified == true)
    |> DB.all()
    |> Map.new(&{&1.id, &1})
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

  defp comment_subscription(%Issue{id: id}, action), do: {String.to_atom("issue_comment_#{action}"), id}
  defp comment_subscription(%CommitLineReview{repo_id: repo_id, commit_oid: commit_oid, blob_oid: blob_oid, hunk: hunk, line: line}, action), do: {String.to_atom("commit_line_review_comment_#{action}"), "#{repo_id}:#{oid_fmt(commit_oid)}:#{oid_fmt(blob_oid)}:#{hunk}:#{line}"}
  defp comment_subscription(%CommitReview{repo_id: repo_id, commit_oid: commit_oid}, action), do: {String.to_atom("commit_review_comment_#{action}"), "#{repo_id}:#{oid_fmt(commit_oid)}"}

  defp comment_subscriptions(thread, action), do: [{String.to_atom("comment_#{action}"), comment_subscription_topic(thread)}, comment_subscription(thread, action)]

  defp comment_subscription_topic(%Comment{id: id}), do: id
  defp comment_subscription_topic(%Issue{id: id}), do: "issue:#{id}"
  defp comment_subscription_topic(%CommitLineReview{id: id}), do: "commit_line_review:#{id}"
  defp comment_subscription_topic(%CommitReview{id: id}), do: "commit_review:#{id}"
  defp comment_subscription_topic(node_id, info), do: comment_subscription_topic(from_relay_id(node_id, info, preload: []))
end
