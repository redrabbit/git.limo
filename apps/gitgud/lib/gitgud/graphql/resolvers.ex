defmodule GitGud.GraphQL.Resolvers do
  @moduledoc """
  Module providing resolution functions for GraphQL related queries.
  """

  alias GitRekt.Git

  alias GitGud.User
  alias GitGud.UserQuery

  alias GitGud.Repo
  alias GitGud.RepoQuery

  @doc """
  Returns a new loader for resolving `Ecto` objects.
  """
  @spec ecto_loader() :: Dataloader.Ecto.t
  def ecto_loader do
    Dataloader.Ecto.new(GitGud.DB, query: &query/2)
  end

  @doc """
  Resolves an user object by username.
  """
  @spec resolve_user(map, map, Absinthe.Resolution.t) :: {:ok, map} | {:error, term}
  def resolve_user(%{} = _root, %{username: username} = _args, _info) do
    if user = UserQuery.by_username(username),
      do: {:ok, user},
    else: {:error, "this given username '#{username}' is not valid"}
  end

  @doc """
  Resolves a repository object by name for a given `user`.
  """
  @spec resolve_user_repo(map, map, Absinthe.Resolution.t) :: {:ok, map} | {:error, term}
  def resolve_user_repo(%User{} = user, %{name: name} = _args, _info) do
    if repo = RepoQuery.user_repository(user, name),
      do: {:ok, repo},
    else: {:error, "this given repository name '#{name}' is not valid"}
  end

  @doc """
  Resolves the default branch object for a given `repo`.
  """
  @spec resolve_repo_head(map, map, Absinthe.Resolution.t) :: {:ok, map} | {:error, term}
  def resolve_repo_head(%Repo{} = repo, %{} = _args, _info) do
    with {:ok, handle} <- Git.repository_open(Repo.workdir(repo)),
         {:ok, name, dwim, oid} <- Git.reference_resolve(handle, "HEAD"), do:
      {:ok, %{name: name, shorthand: dwim, __repo__: repo, __oid__: oid, __git__: handle}}
  end

  @doc """
  Resolves a Git reference object by name for a given `repo`.
  """
  @spec resolve_repo_ref(map, map, Absinthe.Resolution.t) :: {:ok, map} | {:error, term}
  def resolve_repo_ref(%Repo{} = _repo, %{name: "HEAD"} = _args, _info), do: {:error, "reference 'HEAD' not found"}
  def resolve_repo_ref(%Repo{} = repo, %{name: name} = _args, _info) do
    with {:ok, handle} <- Git.repository_open(Repo.workdir(repo)),
         {:ok, dwim, :oid, oid} <- Git.reference_lookup(handle, name), do:
      {:ok, %{name: name, shorthand: dwim, __repo__: repo, __oid__: oid, __git__: handle}}
  end

  def resolve_repo_ref(%Repo{} = _repo, %{dwim: "HEAD"} = _args, _info), do: {:error, "no reference found for shorthand 'HEAD'"}
  def resolve_repo_ref(%Repo{} = repo, %{dwim: dwim} = _args, _info) do
    with {:ok, handle} <- Git.repository_open(Repo.workdir(repo)),
         {:ok, name, :oid, oid} <- Git.reference_dwim(handle, dwim), do:
      {:ok, %{name: name, shorthand: dwim, __repo__: repo, __oid__: oid, __git__: handle}}
  end

  @doc """
  Resolves a repository object for a given Git object.
  """
  @spec resolve_git_repo(map, map, Absinthe.Resolution.t) :: {:ok, map} | {:error, term}
  def resolve_git_repo(%{__repo__: repo} = _git_object, %{} = _args, _info) do
    {:ok, repo}
  end

  @doc """
  Resolves a Git object by revision spec for a given `repo`.
  """
  @spec resolve_git_object(map, map, Absinthe.Resolution.t) :: {:ok, map} | {:error, term}
  def resolve_git_object(%Repo{} = repo, %{revision: revision} = _args, _info) do
    with {:ok, handle} <- Git.repository_open(Repo.workdir(repo)),
         {:ok, obj, obj_type, oid} <- Git.revparse_single(handle, revision), do:
      {:ok, %{oid: oid, __repo__: repo, __git__: handle, __type__: obj_type, __ptr__: obj}}
  end

  def resolve_git_object(%{__repo__: repo, __git__: handle, __oid__: oid} = _git_object, %{} = _args, _info) do
    with {:ok, obj_type, obj} <- Git.object_lookup(handle, oid), do:
      {:ok, %{oid: oid, __repo__: repo, __git__: handle, __type__: obj_type, __ptr__: obj}}
  end

  @doc """
  Resolves the author for a given Git commit object.
  """
  @spec resolve_git_commit_author(map, map, Absinthe.Resolution.t) :: {:ok, map} | {:error, term}
  def resolve_git_commit_author(%{__type__: :commit, __ptr__: commit} = _git_commit, %{} = _args, _info) do
    with {:ok, _name, email, _time, _tz} <- Git.commit_author(commit), do:
      {:ok, UserQuery.by_email(email)}
  end

  @doc """
  Resolves the message for a given Git commit object.
  """
  @spec resolve_git_commit_message(map, map, Absinthe.Resolution.t) :: {:ok, map} | {:error, term}
  def resolve_git_commit_message(%{__type__: :commit, __ptr__: commit} = _git_commit, %{} = _args, _info) do
    Git.commit_message(commit)
  end


  @doc """
  Resolves the Git tree for a given Git commit object.
  """
  @spec resolve_git_commit_tree(map, map, Absinthe.Resolution.t) :: {:ok, map} | {:error, term}
  def resolve_git_commit_tree(%{__type__: :commit, __ptr__: commit, __repo__: repo, __git__: handle} = _git_commit, %{} = _args, _info) do
    with {:ok, oid, tree} <- Git.commit_tree(commit), do:
      {:ok, %{oid: oid, __repo__: repo, __git__: handle, __type__: :tree, __ptr__: tree}}
  end

  @doc """
  Resolves the number of tree entries for a given Git tree object.
  """
  @spec resolve_git_tree_count(map, map, Absinthe.Resolution.t) :: {:ok, map} | {:error, term}
  def resolve_git_tree_count(%{__type__: :tree, __ptr__: tree} = _git_tree, %{} = _args, _info) do
    Git.tree_count(tree)
  end

  @doc """
  Resolves the tree entries for a given Git tree object.
  """
  @spec resolve_git_tree_count(map, map, Absinthe.Resolution.t) :: {:ok, map} | {:error, term}
  def resolve_git_tree_entries(%{__type__: :tree, __ptr__: tree, __repo__: repo, __git__: handle} = _git_tree, %{} = _args, _info) do
    with {:ok, entries} <- Git.tree_list(tree), do:
      {:ok, Enum.map(entries, fn {mode, type, oid, name} -> %{mode: mode, type: type, name: name, __repo__: repo, __git__: handle, __oid__: oid} end)}
  end

  @doc """
  Resolves the content length for a given Git blob object.
  """
  @spec resolve_git_tree_count(map, map, Absinthe.Resolution.t) :: {:ok, map} | {:error, term}
  def resolve_git_blob_size(%{__type__: :blob, __ptr__: blob} = _git_blob, %{} = _args, _info) do
    Git.blob_size(blob)
  end

  @doc """
  Resolves the type for a given Git object.
  """
  @spec resolve_git_object_type(map, Absinthe.Resolution.t) :: atom
  def resolve_git_object_type(%{__type__: :commit} = _git_object, _info), do: :git_commit
  def resolve_git_object_type(%{__type__: :tree} = _git_object, _info), do: :git_tree
  def resolve_git_object_type(%{__type__: :blob} = _git_object, _info), do: :git_blob

  #
  # helpers
  #

  defp query(queryable, _params), do: queryable
end
