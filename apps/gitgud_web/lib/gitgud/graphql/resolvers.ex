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

  import String, only: [to_integer: 1]

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
    {:ok, user_profile_url(GitGud.Web.Endpoint, :show, username)}
  end

  def url(%Repo{} = repo, %{} = _args, _info) do
    {:ok, repository_url(GitGud.Web.Endpoint, :show, repo.owner, repo)}
  end

  def url(%GitReference{repo: repo, shorthand: shorthand} = _reference, %{} = _args, _info) do
    {:ok, repository_url(GitGud.Web.Endpoint, :tree, repo.owner, repo, shorthand, [])}
  end

  @doc """
  Resolves an user object by username.
  """
  @spec user(%{}, %{username: binary}, Absinthe.Resolution.t) :: {:ok, map} | {:error, term}
  def user(%{} = _root, %{username: username} = _args, _info) do
    if user = UserQuery.by_username(username),
      do: {:ok, user},
    else: {:error, "this given username '#{username}' is not valid"}
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
  @spec user_repos(User.t, %{}, Absinthe.Resolution.t) :: {:ok, [Repo.t]} | {:error, term}
  def user_repos(%User{} = user, %{} = _args, %Absinthe.Resolution{context: ctx} = _info) do
    {:ok, RepoQuery.user_repositories(user, viewer: ctx[:current_user])}
  end

  @doc """
  Resolves a repo object by owner and name.
  """
  @spec repo(%{}, %{owner: binary, name: binary}, Absinthe.Resolution.t) :: {:ok, map} | {:error, term}
  def repo(%{} = _root, %{owner: username, name: name} = _args, %Absinthe.Resolution{context: ctx} = _info) do
    if repo = RepoQuery.user_repository(username, name, viewer: ctx[:current_user]),
      do: {:ok, repo},
    else: {:error, "this given repository '#{username}/#{name}' is not valid"}
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
  @spec repo_head(Repo.t, %{}, Absinthe.Resolution.t) :: {:ok, map} | {:error, term}
  def repo_head(%Repo{} = repo, %{} = _args, _info) do
    Repo.git_head(repo)
  end

  @doc """
  Resolves a Git reference object by name or shorthand for a given `repo`.
  """
  @spec repo_refs(Repo.t, %{}, Absinthe.Resolution.t) :: {:ok, [map]} | {:error, term}
  def repo_refs(%Repo{} = repo, %{} = args, _info) do
    Repo.git_references(repo, Map.get(args, :glob, :undefined))
  end

  @doc """
  Resolves a Git reference object by name or shorthand for a given `repo`.
  """
  @spec repo_ref(Repo.t, %{name: binary} | %{shorthand: binary}, Absinthe.Resolution.t) :: {:ok, map} | {:error, term}
  def repo_ref(%Repo{} = repo, %{name: name} = _args, _info), do: Repo.git_reference(repo, name)
  def repo_ref(%Repo{} = repo, %{shorthand: dwim} = _args, _info), do: Repo.git_reference(repo, dwim)

  @doc """
  Resolves the type for the given Git `reference` object.
  """
  @spec git_reference_type(GitReference.t, %{}, Absinthe.Resolution.t) :: {:ok, atom} | {:error, term}
  def git_reference_type(%GitReference{} = reference, %{} = _args, _info) do
    GitReference.type(reference)
  end

  @doc """
  Resolves a Git object for a given `object`.
  """
  @spec git_object(struct, %{rev: binary}, Absinthe.Resolution.t) :: {:ok, map} | {:error, term}
  def git_object(%Repo{} = object, %{rev: rev} = _args, _info), do: Repo.git_revision(object, rev)
  def git_object(%GitReference{} = object, %{} = _args, _info), do: GitReference.commit(object)
  def git_object(%GitTreeEntry{} = object, %{} = _args, _info), do: GitTreeEntry.object(object)

  @doc """
  Resolves the type for a given Git object.
  """
  @spec git_object_type(struct, Absinthe.Resolution.t) :: atom
  def git_object_type(%GitBlob{} = _object, _info), do: :git_blob
  def git_object_type(%GitCommit{} = _object, _info), do: :git_commit
  def git_object_type(%GitTag{} = _object, _info), do: :git_tag
  def git_object_type(%GitTree{} = _object, _info), do: :git_tree

  @doc """
  Resolves the author for a given Git `commit` object.
  """
  @spec git_commit_author(GitCommit.t, %{}, Absinthe.Resolution.t) :: {:ok, map} | {:error, term}
  def git_commit_author(%GitCommit{} = commit, %{} = _args, _info) do
    GitCommit.author(commit)
  end

  @doc """
  Resolves the message for a given Git `commit` object.
  """
  @spec git_commit_message(GitCommit.t, %{}, Absinthe.Resolution.t) :: {:ok, binary} | {:error, term}
  def git_commit_message(%GitCommit{} = commit, %{} = _args, _info) do
    GitCommit.message(commit)
  end


  @doc """
  Resolves the tree for a given Git `commit` object.
  """
  @spec git_commit_tree(GitCommit.t, %{}, Absinthe.Resolution.t) :: {:ok, map} | {:error, term}
  def git_commit_tree(%GitCommit{} = commit, %{} = _args, _info) do
    GitCommit.tree(commit)
  end

  @doc """
  Resolves the number of entries for a given Git `tree` object.
  """
  @spec git_tree_count(GitTree.t, %{}, Absinthe.Resolution.t) :: {:ok, integer} | {:error, term}
  def git_tree_count(%GitTree{} = tree, %{} = _args, _info) do
    GitTree.count(tree)
  end

  @doc """
  Resolves the tree entries for a given Git `tree` object.
  """
  @spec git_tree_entries(GitTree.t, %{}, Absinthe.Resolution.t) :: {:ok, [map]} | {:error, term}
  def git_tree_entries(%GitTree{} = tree, %{} = _args, _info) do
    GitTree.entries(tree)
  end

  @doc """
  Resolves the content length for a given Git `blob` object.
  """
  @spec git_blob_size(GitBlob.t, %{}, Absinthe.Resolution.t) :: {:ok, integer} | {:error, term}
  def git_blob_size(%GitBlob{} = blob, %{} = _args, _info) do
    GitBlob.size(blob)
  end

  #
  # helpers
  #

  defp query(queryable, _params), do: queryable
end
