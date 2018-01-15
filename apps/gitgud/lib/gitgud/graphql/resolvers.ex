defmodule GitGud.GraphQL.Resolvers do

  alias GitRekt.Git
  alias GitGud.UserQuery
  alias GitGud.Repo
  alias GitGud.RepoQuery

  def ecto_loader do
    Dataloader.Ecto.new(GitGud.QuerySet, query: &query/2)
  end

  def resolve_user(%{}, %{username: username}, _info) do
    if user = UserQuery.by_username(username),
      do: {:ok, user},
    else: {:error, "this given username '#{username}' is not valid"}
  end

  def resolve_user_repo(user, %{name: name}, _info) do
    if repo = RepoQuery.user_repository(user, name),
      do: {:ok, repo},
    else: {:error, "this given repository name '#{name}' is not valid"}
  end

  def resolve_repo_head(repo, %{}, _info) do
    with {:ok, handle} <- Git.repository_open(Repo.workdir(repo)),
         {:ok, name, dwim, oid} <- Git.reference_resolve(handle, "HEAD"), do:
      {:ok, %{name: name, shorthand: dwim, __repo__: repo, __oid__: oid, __git__: handle}}
  end

  def resolve_repo_ref(_repo, %{name: "HEAD"}, _info), do: {:error, "reference 'HEAD' not found"}
  def resolve_repo_ref(repo, %{name: name}, _info) do
    with {:ok, handle} <- Git.repository_open(Repo.workdir(repo)),
         {:ok, dwim, :oid, oid} <- Git.reference_lookup(handle, name), do:
      {:ok, %{name: name, shorthand: dwim, __repo__: repo, __oid__: oid, __git__: handle}}
  end

  def resolve_repo_ref(_repo, %{dwim: "HEAD"}, _info), do: {:error, "no reference found for shorthand 'HEAD'"}
  def resolve_repo_ref(repo, %{dwim: dwim}, _info) do
    with {:ok, handle} <- Git.repository_open(Repo.workdir(repo)),
         {:ok, name, :oid, oid} <- Git.reference_dwim(handle, dwim), do:
      {:ok, %{name: name, shorthand: dwim, __repo__: repo, __oid__: oid, __git__: handle}}
  end

  def resolve_git_repo(%{__repo__: repo}, %{}, _info) do
    {:ok, repo}
  end

  def resolve_git_object(%{__repo__: repo, __git__: handle, __oid__: oid}, %{}, _info) do
    with {:ok, obj_type, obj} <- Git.object_lookup(handle, oid), do:
      {:ok, %{oid: oid, __repo__: repo, __git__: handle, __type__: obj_type, __ptr__: obj}}
  end

  def resolve_git_commit_author(%{__type__: :commit, __ptr__: commit}, %{}, _info) do
    with {:ok, _name, email, _time, _tz} <- Git.commit_author(commit), do:
      {:ok, UserQuery.by_email(email)}
  end

  def resolve_git_commit_message(%{__type__: :commit, __ptr__: commit}, %{}, _info) do
    Git.commit_message(commit)
  end

  def resolve_git_commit_tree(%{__type__: :commit, __ptr__: commit, __repo__: repo, __git__: handle}, %{}, _info) do
    with {:ok, oid, tree} <- Git.commit_tree(commit), do:
      {:ok, %{oid: oid, __repo__: repo, __git__: handle, __type__: :tree, __ptr__: tree}}
  end

  def resolve_git_tree_count(%{__type__: :tree, __ptr__: tree}, %{}, _info) do
    Git.tree_count(tree)
  end

  def resolve_git_tree_entries(%{__type__: :tree, __ptr__: tree, __repo__: repo, __git__: handle}, %{}, _info) do
    with {:ok, entries} <- Git.tree_list(tree), do:
      {:ok, Enum.map(entries, fn {mode, type, oid, name} -> %{mode: mode, type: type, name: name, __repo__: repo, __git__: handle, __oid__: oid} end)}
  end

  def resolve_git_blob_size(%{__type__: :blob, __ptr__: blob}, %{}, _info) do
    Git.blob_size(blob)
  end

  def resolve_git_object_type(%{__type__: :commit}, _info), do: :git_commit
  def resolve_git_object_type(%{__type__: :tree}, _info), do: :git_tree
  def resolve_git_object_type(%{__type__: :blob}, _info), do: :git_blob

  #
  # helpers
  #

  defp query(queryable, _params), do: queryable
end
