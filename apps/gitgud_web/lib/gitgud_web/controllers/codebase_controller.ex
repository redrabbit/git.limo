defmodule GitGud.Web.CodebaseController do
  @moduledoc """
  Module responsible for CRUD actions on `GitGud.Repo`.
  """

  use GitGud.Web, :controller

  alias GitGud.DB
  alias GitGud.RepoQuery

  alias GitRekt.GitAgent
  alias GitRekt.{GitBlob, GitTree}

  import GitRekt.Git, only: [oid_fmt: 1, oid_fmt_short: 1, oid_parse: 1]

  plug :put_layout, :repo
  plug :ensure_authenticated when action in [:new, :create, :edit, :update]

  action_fallback GitGud.Web.FallbackController

  @doc """
  Renders a repository codebase overview.
  """
  @spec show(Plug.Conn.t, map) :: Plug.Conn.t
  def show(conn, %{"user_login" => user_login, "repo_name" => repo_name} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      case GitAgent.empty?(repo) do
        {:ok, true} ->
          render(conn, "initialize.html", repo: repo)
        {:ok, false} ->
          with {:ok, head} <- GitAgent.head(repo),
               {:ok, commit} <- GitAgent.peel(repo, head, :commit),
               {:ok, tree} <- GitAgent.tree(repo, commit), do:
            render(conn, "show.html", repo: repo, revision: head, commit: commit, tree: tree, tree_path: [], stats: stats(repo, head))
        {:error, reason} ->
          {:error, reason}
      end
    end || {:error, :not_found}
  end

  @spec new(Plug.Conn.t, map) :: Plug.Conn.t
  def new(conn, %{"user_login" => user_login, "repo_name" => repo_name, "revision" => revision, "path" => []} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      if authorized?(conn.assigns.current_user, repo, :write) do
        with {:ok, head} <- GitAgent.head(repo),
             {:ok, object, reference} <- GitAgent.revision(repo, revision),
             {:ok, tree} <- GitAgent.tree(repo, object) do
          changeset = blob_changeset(%{branch: head.name}, %{})
          render(conn, "new.html", repo: repo, revision: reference || object, tree: tree, tree_path: [], changeset: changeset, stats: stats(repo, reference || object))
        end
      end || {:error, :unauthorized}
    end || {:error, :not_found}
  end

  def new(conn, %{"user_login" => user_login, "repo_name" => repo_name, "revision" => revision, "path" => tree_path} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      if authorized?(conn.assigns.current_user, repo, :write) do
        with {:ok, head} <- GitAgent.head(repo),
             {:ok, object, reference} <- GitAgent.revision(repo, revision),
             {:ok, tree_entry} <- GitAgent.tree_entry_by_path(repo, object, Path.join(tree_path)),
             {:ok, %GitTree{} = tree} <- GitAgent.tree_entry_target(repo, tree_entry) do
          changeset = blob_changeset(%{branch: head.name}, %{})
          render(conn, "new.html", repo: repo, revision: reference || object, tree: tree, tree_path: tree_path, changeset: changeset)
        else
          {:ok, %GitBlob{}} ->
            {:error, :not_found}
          {:error, reason} ->
            {:error, reason}
        end
      end || {:error, :unauthorized}
    end || {:error, :not_found}
  end

  @spec create(Plug.Conn.t, map) :: Plug.Conn.t
  def create(conn, %{"user_login" => user_login, "repo_name" => repo_name, "revision" => revision, "path" => tree_path, "blob" => blob_params} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      current_user = conn.assigns.current_user
      if authorized?(current_user, repo, :write) do
        changeset = blob_changeset(%{}, blob_params)
        with {:ok, object, reference} <- GitAgent.revision(repo, revision),
             {:ok, commit} <- GitAgent.peel(repo, object, :commit),
             {:ok, tree} <- GitAgent.tree(repo, commit) do
          if changeset.valid? do # TODO
            current_user = DB.preload(current_user, :primary_email)
            %{name: blob_name, content: blob_content, message: commit_message_title, branch: update_branch} = changeset.changes
            update_ref = "refs/heads/" <> update_branch
            blob_path = Path.join(tree_path ++ [blob_name])
            author_sig = %{name: current_user.name, email: current_user.primary_email.address, timestamp: DateTime.now!("Etc/UTC")}
            committer_sig = author_sig
            commit_message_body = changeset.changes[:description] || ""
            commit_message =
              if commit_message_body == "",
                do: commit_message_title,
              else: commit_message_title <> "\n\n" <> commit_message_body
            with {:ok, index} <- GitAgent.index(repo),
                  :ok <- GitAgent.index_read_tree(repo, index, tree),
                 {:ok, odb} <- GitAgent.odb(repo),
                 {:ok, blob_oid} <- GitAgent.odb_write(repo, odb, blob_content, :blob),
                  :ok <- GitAgent.index_add(repo, index, blob_oid, blob_path, byte_size(blob_content), 0o100644),
                 {:ok, tree_oid} <- GitAgent.index_write_tree(repo, index),
                 {:ok, commit_oid} <- GitAgent.commit_create(repo, update_ref, author_sig, committer_sig, commit_message, tree_oid, [commit.oid]) do
              conn
              |> put_flash(:info, "Commit #{oid_fmt_short(commit_oid)} created.")
              |> redirect(to: Routes.codebase_path(conn, :commit, user_login, repo_name, oid_fmt(commit_oid)))
            end
          else
            conn
            |> put_flash(:error, "Something went wrong! Please check error(s) below.")
            |> put_status(:bad_request)
            |> render("new.html", repo: repo, revision: reference || object, tree: tree, tree_path: tree_path, changeset: %{changeset|action: :insert})
          end
        end
      end || {:error, :unauthorized}
    end || {:error, :not_found}
  end

  def edit(conn, %{"user_login" => user_login, "repo_name" => repo_name, "revision" => revision, "path" => blob_path} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      if authorized?(conn.assigns.current_user, repo, :write) do
        with {:ok, head} <- GitAgent.head(repo),
             {:ok, object, reference} <- GitAgent.revision(repo, revision),
             {:ok, tree_entry} <- GitAgent.tree_entry_by_path(repo, object, Path.join(blob_path)),
             {:ok, %GitBlob{} = blob} <- GitAgent.tree_entry_target(repo, tree_entry),
             {:ok, blob_content} <- GitAgent.blob_content(repo, blob) do
          changeset = blob_changeset(%{name: List.last(blob_path), content: blob_content, branch: head.name}, %{})
          render(conn, "edit.html", repo: repo, revision: reference || object, blob: blob, tree_path: blob_path, changeset: changeset)
        else
          {:ok, %GitTree{}} ->
            {:error, :not_found}
          {:error, reason} ->
            {:error, reason}
        end
      end || {:error, :unauthorized}
    end || {:error, :not_found}
  end

  @spec update(Plug.Conn.t, map) :: Plug.Conn.t
  def update(conn, %{"user_login" => user_login, "repo_name" => repo_name, "revision" => revision, "path" => blob_path, "blob" => blob_params} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      current_user = conn.assigns.current_user
      if authorized?(current_user, repo, :write) do
        changeset = blob_changeset(%{}, blob_params)
        with {:ok, object, reference} <- GitAgent.revision(repo, revision),
             {:ok, commit} <- GitAgent.peel(repo, object, :commit),
             {:ok, tree} <- GitAgent.tree(repo, commit),
             {:ok, tree_entry} <- GitAgent.tree_entry_by_path(repo, object, Path.join(blob_path)),
             {:ok, %GitBlob{} = blob} <- GitAgent.tree_entry_target(repo, tree_entry) do
          if changeset.valid? do # TODO
            current_user = DB.preload(current_user, :primary_email)
            %{name: blob_name, content: blob_content, message: commit_message_title, branch: update_branch} = changeset.changes
            update_ref = "refs/heads/" <> update_branch
            blob_path = Path.join(List.delete_at(blob_path, -1) ++ [blob_name])
            author_sig = %{name: current_user.name, email: current_user.primary_email.address, timestamp: DateTime.now!("Etc/UTC")}
            committer_sig = author_sig
            commit_message_body = changeset.changes[:description] || ""
            commit_message =
              if commit_message_body == "",
                do: commit_message_title,
              else: commit_message_title <> "\n\n" <> commit_message_body
            with {:ok, index} <- GitAgent.index(repo),
                  :ok <- GitAgent.index_read_tree(repo, index, tree),
                 {:ok, odb} <- GitAgent.odb(repo),
                 {:ok, blob_oid} <- GitAgent.odb_write(repo, odb, blob_content, :blob),
                  :ok <- GitAgent.index_add(repo, index, blob_oid, blob_path, byte_size(blob_content), 0o100644),
                 {:ok, tree_oid} <- GitAgent.index_write_tree(repo, index),
                 {:ok, commit_oid} <- GitAgent.commit_create(repo, update_ref, author_sig, committer_sig, commit_message, tree_oid, [commit.oid]) do
              conn
              |> put_flash(:info, "Commit #{oid_fmt_short(commit_oid)} created.")
              |> redirect(to: Routes.codebase_path(conn, :commit, user_login, repo_name, oid_fmt(commit_oid)))
            end
          else
            conn
            |> put_flash(:error, "Something went wrong! Please check error(s) below.")
            |> put_status(:bad_request)
            |> render("edit.html", repo: repo, revision: reference || object, blob: blob, tree_path: blob_path, changeset: %{changeset|action: :update})
          end
        end
      end || {:error, :unauthorized}
    end || {:error, :not_found}
  end

  @spec delete(Plug.Conn.t, map) :: Plug.Conn.t
  def delete(conn, %{"user_login" => user_login, "repo_name" => repo_name, "revision" => revision, "path" => blob_path, "blob" => blob_params} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      current_user = conn.assigns.current_user
      if authorized?(current_user, repo, :write) do
        changeset = blob_delete_changeset(%{}, blob_params)
        with {:ok, object, reference} <- GitAgent.revision(repo, revision),
             {:ok, commit} <- GitAgent.peel(repo, object, :commit),
             {:ok, tree} <- GitAgent.tree(repo, commit),
             {:ok, tree_entry} <- GitAgent.tree_entry_by_path(repo, object, Path.join(blob_path)),
             {:ok, %GitBlob{} = blob} <- GitAgent.tree_entry_target(repo, tree_entry) do
          if changeset.valid? do # TODO
            current_user = DB.preload(current_user, :primary_email)
            %{message: commit_message_title, branch: update_branch} = changeset.changes
            update_ref = "refs/heads/" <> update_branch
            blob_path = Path.join(blob_path)
            author_sig = %{name: current_user.name, email: current_user.primary_email.address, timestamp: DateTime.now!("Etc/UTC")}
            committer_sig = author_sig
            commit_message_body = changeset.changes[:description] || ""
            commit_message =
              if commit_message_body == "",
                do: commit_message_title,
              else: commit_message_title <> "\n\n" <> commit_message_body
            with {:ok, index} <- GitAgent.index(repo),
                  :ok <- GitAgent.index_read_tree(repo, index, tree),
                  :ok <- GitAgent.index_remove(repo, index, blob_path),
                 {:ok, tree_oid} <- GitAgent.index_write_tree(repo, index),
                 {:ok, commit_oid} <- GitAgent.commit_create(repo, update_ref, author_sig, committer_sig, commit_message, tree_oid, [commit.oid]) do
              conn
              |> put_flash(:info, "Commit #{oid_fmt_short(commit_oid)} created.")
              |> redirect(to: Routes.codebase_path(conn, :commit, user_login, repo_name, oid_fmt(commit_oid)))
            end
          else
            conn
            |> put_flash(:error, "Something went wrong! Please check error(s) below.")
            |> put_status(:bad_request)
            |> render("delete.html", repo: repo, revision: reference || object, blob: blob, tree_path: blob_path, changeset: %{changeset|action: :delete})
          end
        end
      end || {:error, :unauthorized}
    end || {:error, :not_found}
  end

  @doc """
  Renders all branches of a repository.
  """
  @spec branches(Plug.Conn.t, map) :: Plug.Conn.t
  def branches(conn, %{"user_login" => user_login, "repo_name" => repo_name} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      with {:ok, head} <- GitAgent.head(repo),
           {:ok, branches} <- GitAgent.branches(repo), do:
        render(conn, "branch_list.html", repo: repo, head: head, branches: Enum.to_list(branches))
    end || {:error, :not_found}
  end

  @doc """
  Renders all tags of a repository.
  """
  @spec tags(Plug.Conn.t, map) :: Plug.Conn.t
  def tags(conn, %{"user_login" => user_login, "repo_name" => repo_name} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      case GitAgent.tags(repo) do
        {:ok, tags} ->
          render(conn, "tag_list.html", repo: repo, tags: Enum.to_list(tags))
        {:error, reason} ->
          {:error, reason}
      end
    end || {:error, :not_found}
  end

  @doc """
  Renders a single commit.
  """
  @spec commit(Plug.Conn.t, map) :: Plug.Conn.t
  def commit(conn, %{"user_login" => user_login, "repo_name" => repo_name, "oid" => oid} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      with {:ok, object} <- GitAgent.object(repo, oid_parse(oid)),
           {:ok, commit} <- GitAgent.peel(repo, object, :commit),
           {:ok, parents} <- GitAgent.commit_parents(repo, commit),
           {:ok, diff} <- GitAgent.diff(repo, Enum.at(parents, 0), commit), do:
        render(conn, "commit.html", repo: repo, commit: commit, commit_parents: Enum.to_list(parents), diff: diff)
    end || {:error, :not_found}
  end

  @doc """
  Renders all commits for a specific revision.
  """
  @spec history(Plug.Conn.t, map) :: Plug.Conn.t
  def history(conn, %{"user_login" => user_login, "repo_name" => repo_name, "revision" => revision, "path" => []} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      with {:ok, object, reference} <- GitAgent.revision(repo, revision),
           {:ok, history} <- GitAgent.history(repo, object), do:
        render(conn, "commit_list.html", repo: repo, revision: reference || object, commits: history, tree_path: [])
    end || {:error, :not_found}
  end

  def history(conn, %{"user_login" => user_login, "repo_name" => repo_name, "revision" => revision, "path" => tree_path} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      with {:ok, object, reference} <- GitAgent.revision(repo, revision),
           {:ok, history} <- GitAgent.history(repo, object, pathspec: Path.join(tree_path)), do:
        render(conn, "commit_list.html", repo: repo, revision: reference || object, commits: history, tree_path: tree_path)
    end || {:error, :not_found}
  end

  def history(conn, %{"user_login" => user_login, "repo_name" => repo_name} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      case GitAgent.head(repo) do
        {:ok, reference} ->
          redirect(conn, to: Routes.codebase_path(conn, :history, user_login, repo_name, reference, []))
        {:error, reason} ->
          {:error, reason}
      end
    end || {:error, :not_found}
  end

  @doc """
  Renders a tree for a specific revision and path.
  """
  @spec tree(Plug.Conn.t, map) :: Plug.Conn.t
  def tree(conn, %{"user_login" => user_login, "repo_name" => repo_name, "revision" => revision, "path" => []} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      with {:ok, object, reference} <- GitAgent.revision(repo, revision),
           {:ok, commit} <- GitAgent.peel(repo, object, :commit),
           {:ok, tree} <- GitAgent.tree(repo, object), do:
        render(conn, "show.html", repo: repo, revision: reference || object, commit: commit, tree: tree, tree_path: [], stats: stats(repo, reference || object))
    end || {:error, :not_found}
  end

  def tree(conn, %{"user_login" => user_login, "repo_name" => repo_name, "revision" => revision, "path" => tree_path} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      with {:ok, object, reference} <- GitAgent.revision(repo, revision),
           {:ok, commit} <- GitAgent.peel(repo, object, :commit),
           {:ok, tree_entry} <- GitAgent.tree_entry_by_path(repo, object, Path.join(tree_path)),
           {:ok, tree_entry_target} <- GitAgent.tree_entry_target(repo, tree_entry) do
        case tree_entry_target do
          %GitBlob{} ->
            unless reference  do
              conn
              |> put_status(:moved_permanently)
              |> redirect(to: Routes.codebase_path(conn, :blob, repo.owner, repo, revision, tree_path))
            else
              redirect(conn, to: Routes.codebase_path(conn, :blob, repo.owner, repo, revision, tree_path))
            end
          %GitTree{} = tree ->
            render(conn, "tree.html", repo: repo, revision: reference || object, commit: commit, tree: tree, tree_path: tree_path)
        end
      end
    end || {:error, :not_found}
  end

  @doc """
  Renders a blob for a specific revision and path.
  """
  @spec blob(Plug.Conn.t, map) :: Plug.Conn.t
  def blob(conn, %{"user_login" => user_login, "repo_name" => repo_name, "revision" => revision, "path" => blob_path} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      with {:ok, object, reference} <- GitAgent.revision(repo, revision),
           {:ok, commit} <- GitAgent.peel(repo, object, :commit),
           {:ok, tree_entry} <- GitAgent.tree_entry_by_path(repo, object, Path.join(blob_path)),
           {:ok, tree_entry_target} <- GitAgent.tree_entry_target(repo, tree_entry) do
        case tree_entry_target do
          %GitTree{} ->
            unless reference  do
              conn
              |> put_status(:moved_permanently)
              |> redirect(to: Routes.codebase_path(conn, :tree, repo.owner, repo, revision, blob_path))
            else
              redirect(conn, to: Routes.codebase_path(conn, :blob, repo.owner, repo, revision, blob_path))
            end
          %GitBlob{} = blob ->
            render(conn, "blob.html", repo: repo, revision: reference || object, commit: commit, blob: blob, tree_path: blob_path)
        end
      end
    end || {:error, :not_found}
  end

  #
  # Helpers
  #


  defp blob_changeset(blob, params) do
    types = %{name: :string, content: :string, message: :string, description: :string, branch: :string}
    {blob, types}
    |> Ecto.Changeset.cast(params, Map.keys(types))
    |> Ecto.Changeset.validate_required([:name, :content, :message, :branch])
  end

  defp blob_delete_changeset(blob, params) do
    types = %{message: :string, description: :string, branch: :string}
    {blob, types}
    |> Ecto.Changeset.cast(params, Map.keys(types))
    |> Ecto.Changeset.validate_required([:message, :branch])
  end

  defp stats(repo, revision) do
    with {:ok, branches} <- GitAgent.branches(repo),
         {:ok, tags} <- GitAgent.tags(repo),
         {:ok, commit} <- GitAgent.peel(repo, revision, :commit),
         {:ok, history} <- GitAgent.history(repo, commit) do
      %{branches: Enum.count(branches), tags: Enum.count(tags), commits: Enum.count(history)}
    else
      {:error, _reason} ->
        %{commits: 0, branches: 0, tags: 0}
    end
  end
end
