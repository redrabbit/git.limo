defmodule GitGud.GraphQL.Resolvers do
  @moduledoc """
  Module providing resolution functions for GraphQL related queries.
  """

  alias GitGud.User
  alias GitGud.UserQuery
  alias GitGud.Repo
  alias GitGud.RepoQuery

  alias GitGud.GitBlob
  alias GitGud.GitCommit
  alias GitGud.GitReference
  alias GitGud.GitTag
  alias GitGud.GitTreeEntry
  alias GitGud.GitTree

  alias Absinthe.Relay.Connection

  import String, only: [to_integer: 1]
  import Absinthe.Resolution.Helpers, only: [batch: 3]
  import GitRekt.Git, only: [oid_fmt: 1]
  import GitGud.Web.Router.Helpers

  @doc """
  Returns a new loader for resolving `Ecto` objects.
  """
  @spec ecto_loader() :: Dataloader.Ecto.t
  def ecto_loader do
    Dataloader.Ecto.new(GitGud.DB, query: &query/2)
  end

  @doc """
  Resolves a node object type.
  """
  @spec node_type(map, Absinthe.Resolution.t) :: atom | nil
  def node_type(%User{} = _node, _info), do: :user
  def node_type(%Repo{} = _node, _info), do: :repo
  def node_type(_struct, _info), do: nil

  @doc """
  Resolves a node object.
  """
  @spec node(map, Absinthe.Resolution.t) :: {:ok, map} | {:error, term}
  def node(%{id: id, type: :user} = _node_type, info) do
    if user = UserQuery.by_id(to_integer(id)),
      do: {:ok, user},
    else: node(%{id: id}, info)
  end

  def node(%{id: id, type: :repo} = _node_type, %Absinthe.Resolution{context: ctx} = info) do
    if repo = RepoQuery.by_id(to_integer(id), viewer: ctx[:current_user]),
      do: {:ok, repo},
    else: node(%{id: id}, info)
  end

  def node(%{} = _node_type, _info) do
    {:error, "this given node id is not valid"}
  end

  @doc """
  Resolves the URL of the given `resource`.
  """
  @spec url(map, %{}, Absinthe.Resolution.t) :: {:ok, binary} | {:error, term}
  def url(%User{username: username} = _resource, %{} = _args, _info) do
    {:ok, user_url(GitGud.Web.Endpoint, :show, username)}
  end

  def url(%Repo{} = repo, %{} = _args, _info) do
    {:ok, codebase_url(GitGud.Web.Endpoint, :show, repo.owner, repo)}
  end

  def url(%GitReference{repo: repo, name: name} = _reference, %{} = _args, _info) do
    {:ok, codebase_url(GitGud.Web.Endpoint, :tree, repo.owner, repo, name, [])}
  end

  def url(%GitCommit{repo: repo, oid: oid} = _commit, %{} = _args, _info) do
    {:ok, codebase_url(GitGud.Web.Endpoint, :commit, repo.owner, repo, oid_fmt(oid))}
  end

  @doc """
  Resolves an user object by username.
  """
  @spec user(%{}, %{username: binary}, Absinthe.Resolution.t) :: {:ok, User.t} | {:error, term}
  def user(%{} = _root, %{username: username} = _args, _info) do
    if user = UserQuery.by_username(username),
      do: {:ok, user},
    else: {:error, "this given username '#{username}' is not valid"}
  end

  @doc """
  Resolves a list of users for a given search term.
  """
  @spec user_search(map, Absinthe.Resolution.t) :: {:ok, Connection.t} | {:error, term}
  def user_search(%{input: input} = args, _info) do
    Connection.from_list(UserQuery.search(input), args)
  end

  @doc """
  Resolves a repository object by name for a given `user`.
  """
  @spec user_repo(User.t, %{name: binary}, Absinthe.Resolution.t) :: {:ok, Repo.t} | {:error, term}
  def user_repo(%User{} = user, %{name: name} = _args, %Absinthe.Resolution{context: ctx} = _info) do
    if repo = RepoQuery.user_repository(user, name, viewer: ctx[:current_user]),
      do: {:ok, repo},
    else: {:error, "this given repository name '#{name}' is not valid"}
  end

  @doc """
  Resolves all repositories for a given `user`.
  """
  @spec user_repos(map, Absinthe.Resolution.t) :: {:ok, Connection.t} | {:error, term}
  def user_repos(args, %Absinthe.Resolution{source: user, context: ctx} = _info) do
    Connection.from_list(RepoQuery.user_repositories(user, viewer: ctx[:current_user]), args)
  end

  @doc """
  Resolves the owner for a given `repo`.
  """
  @spec repo_owner(Repo.t, %{}, Absinthe.Resolution.t) :: {:ok, User.t} | {:error, term}
  def repo_owner(%Repo{} = repo, %{} = _args, _info) do
    {:ok, repo.owner}
  end

  @doc """
  Resolves the default branch object for a given `repo`.
  """
  @spec repo_head(Repo.t, %{}, Absinthe.Resolution.t) :: {:ok, GitReference.t} | {:error, term}
  def repo_head(%Repo{} = repo, %{} = _args, _info) do
    Repo.git_head(repo)
  end

  @doc """
  Resolves a Git reference object by name for a given `repo`.
  """
  @spec repo_ref(Repo.t, %{name: binary}, Absinthe.Resolution.t) :: {:ok, GitReference.t} | {:error, term}
  def repo_ref(%Repo{} = repo, %{name: name} = _args, _info) do
    Repo.git_reference(repo, name)
  end

  @doc """
  Resolves all Git reference objects for a given `repo`.
  """
  @spec repo_refs(map, Absinthe.Resolution.t) :: {:ok, Connection.t} | {:error, term}
  def repo_refs(args, %Absinthe.Resolution{source: repo} = _source) do
    case Repo.git_references(repo, Map.get(args, :glob, :undefined)) do
      {:ok, stream} ->
        Connection.from_list(Enum.to_list(stream), args)
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Resolves a Git tag object by name for a given `repo`.
  """
  @spec repo_tag(Repo.t, %{name: binary}, Absinthe.Resolution.t) :: {:ok, GitReference.t | GitTag.t} | {:error, term}
  def repo_tag(%Repo{} = repo, %{name: name} = _args, _info) do
    Repo.git_tag(repo, name)
  end

  @doc """
  Resolves all Git tag objects for a given `repo`.
  """
  @spec repo_tags(map, Absinthe.Resolution.t) :: {:ok, Connection.t} | {:error, term}
  def repo_tags(args, %Absinthe.Resolution{source: repo} = _source) do
    case Repo.git_tags(repo) do
      {:ok, stream} ->
        Connection.from_list(Enum.to_list(stream), args)
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
  Resolves a Git object for the given `repo`.
  """
  @spec git_object(Repo.t, %{rev: binary}, Absinthe.Resolution.t) :: {:ok, Repo.git_object} | {:error, term}
  def git_object(%Repo{} = repo, %{rev: rev} = _args, _info) do
    Repo.git_revision(repo, rev)
  end

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
  Resolves the type for the given Git `reference` object.
  """
  @spec git_reference_type(GitReference.t, %{}, Absinthe.Resolution.t) :: {:ok, GitReference.type} | {:error, term}
  def git_reference_type(%GitReference{} = reference, %{} = _args, _info) do
    GitReference.type(reference)
  end

  @doc """
  Resolves the commit history starting from the given Git `reference` object.
  """
  @spec repo_tags(map, Absinthe.Resolution.t) :: {:ok, Connection.t} | {:error, term}
  def git_commit_history(args, %Absinthe.Resolution{source: commit} = _source) do
    case GitCommit.history(commit) do
      {:ok, stream} ->
        Connection.from_list(Enum.to_list(stream), args)
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Resolves the author for a given Git `commit` object.
  """
  @spec git_commit_author(GitCommit.t, %{}, Absinthe.Resolution.t) :: {:ok, User.t | map} | {:error, term}
  def git_commit_author(%GitCommit{} = commit, %{} = _args, _info) do
    case GitCommit.author(commit) do
      {:ok, {name, email, _datetime}} ->
        batch({__MODULE__, :batch_users_by_email}, email, fn users ->
          {:ok, users[email] || %{name: name, email: email}}
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
  Resolves the tree for a given Git `commit` object.
  """
  @spec git_commit_tree(GitCommit.t, %{}, Absinthe.Resolution.t) :: {:ok, GitTree.t} | {:error, term}
  def git_commit_tree(%GitCommit{} = commit, %{} = _args, _info) do
    GitCommit.tree(commit)
  end

  @doc """
  Resolves the name for a given Git `tag` object.
  """
  @spec git_tag_name(GitTag.t, %{}, Absinthe.Resolution.t) :: {:ok, binary} | {:error, term}
  def git_tag_name(%GitTag{} = tag, %{} = _args, _info) do
    GitTag.name(tag)
  end

  @doc """
  Resolves the author for a given Git `tag` object.
  """
  @spec git_tag_author(GitTag.t, %{}, Absinthe.Resolution.t) :: {:ok, User.t | map} | {:error, term}
  def git_tag_author(%GitTag{} = tag, %{} = _args, _info) do
    case GitTag.author(tag) do
      {:ok, {name, email, _datetime}} ->
        batch({__MODULE__, :batch_users_by_email}, email, fn users ->
          {:ok, users[email] || %{name: name, email: email}}
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
  Resolves the tree entries for a given Git `tree` object.
  """
  @spec git_tree_entries(map, Absinthe.Resolution.t) :: {:ok, Connection.t} | {:error, term}
  def git_tree_entries(args, %Absinthe.Resolution{source: tree} = _source) do
    case GitTree.entries(tree) do
      {:ok, stream} ->
        Connection.from_list(Enum.to_list(stream), args)
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Returns the underlying Git object for a given Git `tree_entry` object.
  """
  @spec git_tree_entry_object(Repo.t, %{}, Absinthe.Resolution.t) :: {:ok, GitTree.t | GitBlob.t} | {:error, term}
  def git_tree_entry_object(%GitTreeEntry{} = tree_entry, %{} = _args, _info) do
    GitTreeEntry.object(tree_entry)
  end

  @doc """
  Resolves the content length for a given Git `blob` object.
  """
  @spec git_blob_size(GitBlob.t, %{}, Absinthe.Resolution.t) :: {:ok, integer} | {:error, term}
  def git_blob_size(%GitBlob{} = blob, %{} = _args, _info) do
    GitBlob.size(blob)
  end

  @doc false
  @spec batch_users_by_email(any, [binary]) :: map
  def batch_users_by_email(_, emails) do
    emails
    |> Enum.uniq()
    |> UserQuery.by_email()
    |> Map.new(&{&1.email, &1})
  end

  #
  # helpers
  #

  defp query(queryable, _params), do: queryable
end
