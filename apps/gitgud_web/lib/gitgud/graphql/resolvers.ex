defmodule GitGud.GraphQL.Resolvers do
  @moduledoc """
  Module providing resolution functions for GraphQL related queries.
  """

  alias GitRekt.Git

  alias GitGud.User
  alias GitGud.UserQuery
  alias GitGud.Repo
  alias GitGud.RepoQuery

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
  Returns the source id for the given Relay `global_id`.
  """
  @spec from_relay_id(Absinthe.Relay.Node.global_id) :: pos_integer | nil
  def from_relay_id(global_id) do
    case Absinthe.Relay.Node.from_global_id(global_id, GitGud.GraphQL.Schema) do
      {:ok, nil} -> nil
      {:ok, node} -> String.to_integer(node.id)
      {:error, _reason} -> nil
    end
  end

  @doc """
  Returns the Relay global id for the given `node`.
  """
  @spec to_relay_id(Ecto.Schema.t) :: Absinthe.Relay.Node.global_id | nil
  def to_relay_id(node) do
    case Ecto.primary_key(node) do
      [{_, id}] -> to_relay_id(node_type(node, nil), id)
    end
  end

  @doc """
  Returns the Relay global id for the given `source_id`.
  """
  @spec to_relay_id(atom | binary, pos_integer) :: Absinthe.Relay.Node.global_id | nil
  def to_relay_id(node_type, source_id) do
    Absinthe.Relay.Node.to_global_id(node_type, source_id, GitGud.GraphQL.Schema)
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

  def url(%{__type__: :ref, __repo__: repo} = spec, %{} = _args, _info) do
    {:ok, repository_url(GitGud.Web.Endpoint, :tree, repo.owner, repo, spec.shorthand, [])}
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
    with {:ok, handle} <- Git.repository_open(Repo.workdir(repo)),
         {:ok, name, dwim, oid} <- Git.reference_resolve(handle, "HEAD"), do:
      {:ok, %{oid: oid, name: name, shorthand: dwim, __type__: :ref, __repo__: repo, __git__: handle}}
  end

  @doc """
  Resolves a Git reference object by name or shorthand for a given `repo`.
  """
  @spec repo_refs(Repo.t, %{}, Absinthe.Resolution.t) :: {:ok, [map]} | {:error, term}
  def repo_refs(%Repo{} = repo, %{} = args, _info) do
    with {:ok, handle} <- Git.repository_open(Repo.workdir(repo)),
         {:ok, stream} <- Git.reference_stream(handle, Map.get(args, :glob, :undefined)), do:
      {:ok, transform_refs(repo, handle, stream)}
  end

  @doc """
  Resolves a Git reference object by name or shorthand for a given `repo`.
  """
  @spec repo_ref(Repo.t, %{name: binary} | %{shorthand: binary}, Absinthe.Resolution.t) :: {:ok, map} | {:error, term}
  def repo_ref(%Repo{} = repo, %{name: name} = _args, info) when name == "HEAD", do: repo_head(repo, %{}, info)
  def repo_ref(%Repo{} = repo, %{name: name} = _args, _info) do
    with {:ok, handle} <- Git.repository_open(Repo.workdir(repo)),
         {:ok, dwim, :oid, oid} <- Git.reference_lookup(handle, name), do:
      {:ok, %{oid: oid, name: name, shorthand: dwim, __type__: :ref, __repo__: repo, __git__: handle}}
  end

  def repo_ref(%Repo{} = repo, %{shorthand: dwim} = _args, info) when dwim == "HEAD", do: repo_head(repo, %{}, info)
  def repo_ref(%Repo{} = repo, %{shorthand: dwim} = _args, _info) do
    with {:ok, handle} <- Git.repository_open(Repo.workdir(repo)),
         {:ok, name, :oid, oid} <- Git.reference_dwim(handle, dwim), do:
      {:ok, %{oid: oid, name: name, shorthand: dwim, __type__: :ref, __repo__: repo, __git__: handle}}
  end

  @doc """
  Resolves a repository object for a given Git object.
  """
  @spec git_repo(map, %{}, Absinthe.Resolution.t) :: {:ok, Repo.t} | {:error, term}
  def git_repo(%{__repo__: repo} = _git_object, %{} = _args, _info) do
    {:ok, repo}
  end

  @doc """
  Resolves the type for a Git reference object.
  """
  @spec git_reference_type(map, %{}, Absinthe.Resolution.t) :: {:ok, atom} | {:error, term}
  def git_reference_type(%{name: "refs/heads/" <> shorthand, shorthand: shorthand} = _git_reference, %{} = _args, _info), do: {:ok, :branch}
  def git_reference_type(%{name: "refs/tags/"  <> shorthand, shorthand: shorthand} = _git_reference, %{} = _args, _info), do: {:ok, :tag}

  @doc """
  Resolves a Git object by revision spec for a given `repo`.
  """
  @spec git_object(map, %{rev: binary}, Absinthe.Resolution.t) :: {:ok, map} | {:error, term}
  def git_object(%Repo{} = repo, %{rev: rev} = _args, _info) do
    with {:ok, handle} <- Git.repository_open(Repo.workdir(repo)),
         {:ok, obj, obj_type, oid} <- Git.revparse_single(handle, rev), do:
      {:ok, %{oid: oid, __repo__: repo, __git__: handle, __type__: obj_type, __ptr__: obj}}
  end

  @doc """
  Resolves a Git object interface.
  """
  @spec git_object_interface(map, %{}, Absinthe.Resolution.t) :: {:ok, map} | {:error, term}
  def git_object_interface(%{oid: oid, __repo__: repo, __git__: handle} = _git_object, %{} = _args, _info) do
    with {:ok, obj_type, obj} <- Git.object_lookup(handle, oid), do:
      {:ok, %{oid: oid, __repo__: repo, __git__: handle, __type__: obj_type, __ptr__: obj}}
  end

  @doc """
  Resolves the author for a given Git commit object.
  """
  @spec git_commit_author(map, %{}, Absinthe.Resolution.t) :: {:ok, map} | {:error, term}
  def git_commit_author(%{__type__: :commit, __ptr__: commit} = _git_commit, %{} = _args, _info) do
    with {:ok, _name, email, _time, _tz} <- Git.commit_author(commit), do:
      {:ok, UserQuery.by_email(email)}
  end

  @doc """
  Resolves the message for a given Git commit object.
  """
  @spec git_commit_message(map, %{}, Absinthe.Resolution.t) :: {:ok, binary} | {:error, term}
  def git_commit_message(%{__type__: :commit, __ptr__: commit} = _git_commit, %{} = _args, _info) do
    Git.commit_message(commit)
  end


  @doc """
  Resolves the Git tree for a given Git commit object.
  """
  @spec git_commit_tree(map, %{}, Absinthe.Resolution.t) :: {:ok, map} | {:error, term}
  def git_commit_tree(%{__type__: :commit, __ptr__: commit, __repo__: repo, __git__: handle} = _git_commit, %{} = _args, _info) do
    with {:ok, oid, tree} <- Git.commit_tree(commit), do:
      {:ok, %{oid: oid, __repo__: repo, __git__: handle, __type__: :tree, __ptr__: tree}}
  end

  @doc """
  Resolves the number of tree entries for a given Git tree object.
  """
  @spec git_tree_count(map, %{}, Absinthe.Resolution.t) :: {:ok, integer} | {:error, term}
  def git_tree_count(%{__type__: :tree, __ptr__: tree} = _git_tree, %{} = _args, _info) do
    Git.tree_count(tree)
  end

  @doc """
  Resolves the tree entries for a given Git tree object.
  """
  @spec git_tree_entries(map, %{}, Absinthe.Resolution.t) :: {:ok, [map]} | {:error, term}
  def git_tree_entries(%{__type__: :tree, __ptr__: tree, __repo__: repo, __git__: handle} = _git_tree, %{} = _args, _info) do
    with {:ok, entries} <- Git.tree_list(tree), do:
      {:ok, Enum.map(entries, fn {mode, type, oid, name} -> %{oid: oid, mode: mode, type: type, name: name, __repo__: repo, __git__: handle} end)}
  end

  @doc """
  Resolves the content length for a given Git blob object.
  """
  @spec git_blob_size(map, %{}, Absinthe.Resolution.t) :: {:ok, integer} | {:error, term}
  def git_blob_size(%{__type__: :blob, __ptr__: blob} = _git_blob, %{} = _args, _info) do
    Git.blob_size(blob)
  end

  @doc """
  Resolves the type for a given Git object.
  """
  @spec git_object_type(map, Absinthe.Resolution.t) :: atom
  def git_object_type(%{__type__: :commit} = _git_object, _info), do: :git_commit
  def git_object_type(%{__type__: :tree} = _git_object, _info), do: :git_tree
  def git_object_type(%{__type__: :blob} = _git_object, _info), do: :git_blob

  #
  # helpers
  #

  defp query(queryable, _params), do: queryable

  defp transform_refs(repo, handle, stream) do
    Enum.map(stream, fn {name, shorthand, :oid, oid} ->
      %{oid: oid, name: name, shorthand: shorthand, __type__: :ref, __repo__: repo, __git__: handle}
    end)
  end
end
