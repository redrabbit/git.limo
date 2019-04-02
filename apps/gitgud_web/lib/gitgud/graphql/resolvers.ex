defmodule GitGud.GraphQL.Resolvers do
  @moduledoc """
  Module providing resolution functions for GraphQL related queries.
  """

  alias GitGud.DB
  alias GitGud.DBQueryable

  alias GitGud.User
  alias GitGud.UserQuery
  alias GitGud.Repo
  alias GitGud.RepoQuery
  alias GitGud.Comment
  alias GitGud.CommitLineReview

  alias GitGud.GitBlob
  alias GitGud.GitCommit
  alias GitGud.GitReference
  alias GitGud.GitTag
  alias GitGud.GitTreeEntry
  alias GitGud.GitTree

  alias Absinthe.Relay.Connection

  alias GitGud.Web.Router.Helpers, as: Routes

  import String, only: [to_integer: 1]
  import Absinthe.Resolution.Helpers, only: [batch: 3]

  import GitRekt.Git, only: [oid_fmt: 1]
  import GitGud.GraphQL.Schema, only: [from_relay_id: 1]

  @doc """
  Resolves a node object type.
  """
  @spec node_type(map, Absinthe.Resolution.t) :: atom | nil
  def node_type(%User{} = _node, _info), do: :user
  def node_type(%Repo{} = _node, _info), do: :repo
  def node_type(%Comment{} = _node, _info), do: :comment
  def node_type(%CommitLineReview{} = _node, _info), do: :git_commit_line_review
  def node_type(_struct, _info), do: nil

  @doc """
  Resolves a node object.
  """
  @spec node(map, Absinthe.Resolution.t) :: {:ok, map} | {:error, term}
  def node(%{id: id, type: :user} = _node_type, info) do
    if user = UserQuery.by_id(to_integer(id), preload: :public_email),
      do: {:ok, user},
    else: node(%{id: id}, info)
  end

  def node(%{id: id, type: :repo} = _node_type, %Absinthe.Resolution{context: ctx} = info) do
    if repo = RepoQuery.by_id(to_integer(id), viewer: ctx[:current_user], preload: [owner: :public_email]),
      do: {:ok, repo},
    else: node(%{id: id}, info)
  end

  def node(%{id: id, type: :comment} = _node_type, info) do
    if comment = DB.get(Comment, to_integer(id)),
      do: {:ok, DB.preload(comment, [:author])},
    else: node(%{id: id}, info)
  end

  def node(%{id: id, type: :git_commit_line_review} = _node_type, info) do
    if review = DB.get(CommitLineReview, to_integer(id)),
      do: {:ok, DB.preload(review, [:repo, comments: :author])},
    else: node(%{id: id}, info)
  end

  def node(%{} = _node_type, _info) do
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

  def url(%GitReference{repo: repo, name: name} = _reference, %{} = _args, _info) do
    {:ok, Routes.codebase_url(GitGud.Web.Endpoint, :tree, repo.owner, repo, name, [])}
  end

  def url(%GitCommit{repo: repo, oid: oid} = _commit, %{} = _args, _info) do
    {:ok, Routes.codebase_url(GitGud.Web.Endpoint, :commit, repo.owner, repo, oid_fmt(oid))}
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
    case Earmark.as_html(user.bio || "") do
      {:ok, html, []} ->
        {:ok, html}
      {:error, reason} ->
        {:error, reason}
    end
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
      do: {:ok, repo},
    else: {:error, "this given repository name '#{name}' is not valid"}
  end

  @doc """
  Resolves all repositories for a given `user`.
  """
  @spec user_repos(map, Absinthe.Resolution.t) :: {:ok, Connection.t} | {:error, term}
  def user_repos(args, %Absinthe.Resolution{source: user, context: ctx} = _info) do
    query = DBQueryable.query({RepoQuery, :user_repos_query}, user, viewer: ctx[:current_user], preload: [owner: :public_email])
    Connection.from_query(query, &DB.all/1, args)
  end

  def repo(%{owner: owner, name: name}, %Absinthe.Resolution{context: ctx} = _info) do
    if repo = RepoQuery.user_repo(owner, name, viewer: ctx[:current_user], preload: [owner: :public_email]),
      do: {:ok, repo},
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
    case Earmark.as_html(repo.description || "") do
      {:ok, html, []} ->
        {:ok, html}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Resolves the default branch object for a given `repo`.
  """
  @spec repo_head(Repo.t, %{}, Absinthe.Resolution.t) :: {:ok, GitReference.t} | {:error, term}
  def repo_head(%Repo{} = repo, %{} = _args, _info) do
    repo
    |> Repo.load()
    |> Repo.git_head()
  end

  @doc """
  Resolves a Git reference object by name for a given `repo`.
  """
  @spec repo_ref(Repo.t, %{name: binary}, Absinthe.Resolution.t) :: {:ok, GitReference.t} | {:error, term}
  def repo_ref(%Repo{} = repo, %{name: name} = _args, _info) do
    repo
    |> Repo.load()
    |> Repo.git_reference(name)
  end

  @doc """
  Resolves all Git reference objects for a given `repo`.
  """
  @spec repo_refs(map, Absinthe.Resolution.t) :: {:ok, Connection.t} | {:error, term}
  def repo_refs(args, %Absinthe.Resolution{source: repo} = _source) do
    repo = Repo.load(repo)
    case Repo.git_references(repo, Map.get(args, :glob, :undefined)) do
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
    repo
    |> Repo.load()
    |> Repo.git_tag(name)
  end

  @doc """
  Resolves all Git tag objects for a given `repo`.
  """
  @spec repo_tags(map, Absinthe.Resolution.t) :: {:ok, Connection.t} | {:error, term}
  def repo_tags(args, %Absinthe.Resolution{source: repo} = _source) do
    repo = Repo.load(repo)
    case Repo.git_tags(repo) do
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
  Resolves the Git target for the given Git `reference` object.
  """
  @spec git_reference_target(GitReference.t, %{}, Absinthe.Resolution.t) :: {:ok, Repo.git_object} | {:error, term}
  def git_reference_target(%GitReference{} = reference, %{} = _args, _info) do
    GitReference.target(reference)
  end

  @doc """
  Resolves the commit history starting from the given Git `revision` object.
  """
  @spec git_history(map, Absinthe.Resolution.t) :: {:ok, Connection.t} | {:error, term}
  def git_history(args, %Absinthe.Resolution{source: revision} = _source) do
    case Repo.git_history(revision) do
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
  def git_commit_parents(args,  %Absinthe.Resolution{source: commit} = _source) do
    case GitCommit.parents(commit) do
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
  def git_commit_author(%GitCommit{} = commit, %{} = _args,  %Absinthe.Resolution{context: ctx} = _info) do
    case GitCommit.author(commit) do
      {:ok, %{email: email} = author} ->
        batch({__MODULE__, :batch_users_by_email, ctx[:current_user]}, email, fn users ->
          {:ok, users[email] || author}
        end)
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Resolves the message for a given Git `commit` object.
  """
  @spec git_commit_message(GitCommit.t, %{}, Absinthe.Resolution.t) :: {:ok, binary} | {:error, term}
  def git_commit_message(%GitCommit{} = commit, %{} = _args, _info) do
    GitCommit.message(commit)
  end

  @doc """
  Resolves the timestamp for a given Git `commit` object.
  """
  @spec git_commit_timestamp(GitCommit.t, %{}, Absinthe.Resolution.t) :: {:ok, DateTime.t} | {:error, term}
  def git_commit_timestamp(%GitCommit{} = commit, %{} = _args, _info) do
    GitCommit.timestamp(commit)
  end

  @doc """
  Resolves the line-review for a given Git `commit` object.
  """
  @spec git_commit_line_review(GitCommit.t, %{}, Absinthe.Resolution.t) :: {:ok, CommitLineReview.t} | {:error, term}
  def git_commit_line_review(%GitCommit{} = commit, %{blob_oid: blob_oid, hunk: hunk, line: line} = _args,  _info) do
    if review = GitCommit.review(commit, blob_oid, hunk, line),
      do: {:ok, review},
    else: {:error, "there is no line-review for the given args"}
  end

  @doc """
  Resolves the author for a given Git `tag` object.
  """
  @spec git_tag_author(GitTag.t, %{}, Absinthe.Resolution.t) :: {:ok, User.t | map} | {:error, term}
  def git_tag_author(%GitTag{} = tag, %{} = _args, %Absinthe.Resolution{context: ctx} = _info) do
    case GitTag.author(tag) do
      {:ok, %{email: email} = author} ->
        batch({__MODULE__, :batch_users_by_email, ctx[:current_user]}, email, fn users ->
          {:ok, users[email] || author}
        end)
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Resolves the message for a given Git `tag` object.
  """
  @spec git_tag_message(GitTag.t, %{}, Absinthe.Resolution.t) :: {:ok, binary} | {:error, term}
  def git_tag_message(%GitTag{} = tag, %{} = _args, _info) do
    GitTag.message(tag)
  end

  @doc """
  Resolves the Git target for the given Git `tag` object.
  """
  @spec git_tag_target(GitTag.t, %{}, Absinthe.Resolution.t) :: {:ok, Repo.git_object} | {:error, term}
  def git_tag_target(%GitTag{} = tag, %{} = _args, _info) do
    GitTag.target(tag)
  end

  @doc """
  Resolves the type for a given Git `tag`.
  """
  @spec git_tag_type(GitReference.t | GitTag.t, Absinthe.Resolution.t) :: {:ok, atom} | {:error, term}
  def git_tag_type(%GitReference{} = _tag, _info), do: :git_reference
  def git_tag_type(%GitTag{} = _tag, _info), do: :git_annotated_tag

  @doc """
  Resolves the tree for a given Git `commit` object.
  """
  @spec git_tree(Repo.git_revision, %{}, Absinthe.Resolution.t) :: {:ok, GitTree.t} | {:error, term}
  def git_tree(revision, %{} = _args, _info) do
    Repo.git_tree(revision)
  end

  @doc """
  Resolves the tree entries for a given Git `tree` object.
  """
  @spec git_tree_entries(map, Absinthe.Resolution.t) :: {:ok, Connection.t} | {:error, term}
  def git_tree_entries(args, %Absinthe.Resolution{source: tree} = _source) do
    case GitTree.entries(tree) do
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
  def git_tree_entry_target(%GitTreeEntry{} = tree_entry, %{} = _args, _info) do
    GitTreeEntry.target(tree_entry)
  end

  @doc """
  Resolves the content length for a given Git `blob` object.
  """
  @spec git_blob_size(GitBlob.t, %{}, Absinthe.Resolution.t) :: {:ok, integer} | {:error, term}
  def git_blob_size(%GitBlob{} = blob, %{} = _args, _info) do
    GitBlob.size(blob)
  end

  def create_git_commit_line_comment(_parent, %{repo_id: repo_id, commit_oid: commit_oid, blob_oid: blob_oid, hunk: hunk, line: line, body: body}, %Absinthe.Resolution{context: ctx}) do
    CommitLineReview.add_comment(from_relay_id(repo_id), commit_oid, blob_oid, hunk, line, ctx[:current_user], body)
  end

  def update_comment(_parent, %{id: comment_id, body: body}, %Absinthe.Resolution{context: ctx}) do
    if user = ctx[:current_user] do
      if comment = DB.get(Comment, from_relay_id(comment_id)) do
        if comment.author_id == user.id do
          {:ok, comment} = Comment.update(comment, body: body)
          {:ok, DB.preload(comment, :author)}
        end
      end
    end
  end

  def delete_comment(_parent, %{id: comment_id}, %Absinthe.Resolution{context: ctx}) do
    if user = ctx[:current_user] do
      if comment = DB.get(Comment, from_relay_id(comment_id)) do
        if comment.author_id == user.id do
          Comment.delete(comment)
        end
      end
    end
  end

  @doc """
  Resolves the HTML content of a given `comment`.
  """
  @spec comment_html(Comment.t, %{}, Absinthe.Resolution.t) :: {:ok, integer} | {:error, term}
  def comment_html(comment, %{} = _args, _info) do
    case Earmark.as_html(comment.body) do
      {:ok, html, []} ->
        {:ok, html}
      {:error, reason} ->
        {:error, reason}
    end
  end

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

  defp slice_stream(stream, args) do
    count = Enum.count(stream.enum)
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
end
