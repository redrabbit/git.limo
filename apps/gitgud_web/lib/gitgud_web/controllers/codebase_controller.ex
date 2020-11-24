defmodule GitGud.Web.CodebaseController do
  @moduledoc """
  Module responsible for CRUD actions on `GitGud.Repo`.
  """

  use GitGud.Web, :controller

  alias GitGud.DB
  alias GitGud.RepoQuery
  alias GitGud.RepoStorage

  alias GitRekt.GitAgent
  alias GitRekt.{GitRef, GitBlob, GitTree}

  import GitRekt.Git, only: [oid_fmt: 1, oid_parse: 1]

  plug :put_layout, :repo
  plug :ensure_authenticated when action in [:new, :create, :edit, :update, :confirm_delete, :delete]

  action_fallback GitGud.Web.FallbackController

  @doc """
  Renders a repository codebase overview.
  """
  @spec show(Plug.Conn.t, map) :: Plug.Conn.t
  def show(conn, %{"user_login" => user_login, "repo_name" => repo_name} = _params) do
    user = current_user(conn)
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: user, preload: :contributors) do
      with {:ok, agent} <- GitAgent.unwrap(repo),
           {:ok, false} <- GitAgent.empty?(agent),
           {:ok, head} <- GitAgent.head(agent),
           {:ok, commit} <- GitAgent.peel(agent, head, :commit),
           {:ok, tree} <- GitAgent.tree(agent, commit) do
        breadcrumb = %{action: :tree, cwd?: true, tree?: true}
        render(conn, "show.html", repo: repo, agent: agent, revision: head, commit: commit, tree: tree, tree_path: [], breadcrumb: breadcrumb, stats: stats(repo, agent, head))
      else
        {:ok, true} ->
          if authorized?(user, repo, :read),
            do: render(conn, "initialize.html", repo: repo),
          else: {:error, :not_found}
        {:error, reason} ->
          {:error, reason}
      end
    end || {:error, :not_found}
  end

  @doc """
  Renders a blob creation form.
  """
  @spec new(Plug.Conn.t, map) :: Plug.Conn.t
  def new(conn, %{"user_login" => user_login, "repo_name" => repo_name, "revision" => revision, "path" => []} = _params) do
    user = current_user(conn)
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: user, preload: :contributors) do
      if authorized?(user, repo, :write) do
        with {:ok, agent} <- GitAgent.unwrap(repo),
             {:ok, {object, %GitRef{type: :branch, name: branch_name} = reference}} <- GitAgent.revision(agent, revision),
             {:ok, tree} <- GitAgent.tree(agent, object) do
          breadcrumb = %{action: :tree, cwd?: true, tree?: true}
          changeset = blob_commit_changeset(%{branch: branch_name}, %{})
          render(conn, "new.html", repo: repo, agent: agent, revision: reference, tree: tree, tree_path: [], changeset: changeset, breadcrumb: breadcrumb, stats: stats(repo, agent, reference || object))
        else
          {:ok, {_object, _reference}} ->
            {:error, :not_found}
          {:error, reason} ->
            {:error, reason}
        end
      end || {:error, :unauthorized}
    end || {:error, :not_found}
  end

  def new(conn, %{"user_login" => user_login, "repo_name" => repo_name, "revision" => revision, "path" => tree_path} = _params) do
    user = current_user(conn)
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: user) do
      if authorized?(user, repo, :write) do
        with {:ok, agent} <- GitAgent.unwrap(repo),
             {:ok, {object, %GitRef{type: :branch, name: branch_name} = reference}} <- GitAgent.revision(agent, revision),
             {:ok, tree_entry} <- GitAgent.tree_entry_by_path(agent, object, Path.join(tree_path)),
             {:ok, %GitTree{} = tree} <- GitAgent.tree_entry_target(agent, tree_entry) do
          breadcrumb = %{action: :tree, cwd?: true, tree?: true}
          changeset = blob_commit_changeset(%{branch: branch_name}, %{})
          render(conn, "new.html", repo: repo, agent: agent, revision: reference, tree: tree, tree_path: tree_path, changeset: changeset, breadcrumb: breadcrumb)
        else
          {:ok, {_object, _reference}} ->
            {:error, :not_found}
          {:ok, %GitBlob{}} ->
            {:error, :not_found}
          {:error, reason} ->
            {:error, reason}
        end
      end || {:error, :unauthorized}
    end || {:error, :not_found}
  end

  @doc """
  Creates a new blob.
  """
  @spec create(Plug.Conn.t, map) :: Plug.Conn.t
  def create(conn, %{"user_login" => user_login, "repo_name" => repo_name, "revision" => revision, "path" => tree_path, "commit" => commit_params} = _params) do
    user = current_user(conn)
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: user) do
      if authorized?(user, repo, :write) do
        with {:ok, agent} <- GitAgent.unwrap(repo),
             {:ok, {object, reference}} <- GitAgent.revision(agent, revision),
             {:ok, commit} <- GitAgent.peel(agent, object, :commit),
             {:ok, tree} <- GitAgent.tree(agent, commit) do
          breadcrumb = %{action: :tree, cwd?: true, tree?: true}
          changeset = blob_commit_changeset(%{}, commit_params)
          if changeset.valid? do # TODO
            blob_name = blob_changeset_name(changeset)
            blob_path = Path.join(tree_path ++ [blob_name])
            case GitAgent.tree_entry_by_path(agent, tree, blob_path) do
              {:ok, _tree_entry} ->
                changeset = Ecto.Changeset.add_error(changeset, :name, "has already been taken")
                conn
                |> put_flash(:error, "Something went wrong! Please check error(s) below.")
                |> put_status(:bad_request)
                |> render("new.html", repo: repo, agent: agent, revision: reference || object, tree: tree, tree_path: tree_path, changeset: %{changeset|action: :insert}, breadcrumb: breadcrumb)
              {:error, _reason} ->
                blob_content = blob_changeset_content(changeset)
                commit_author_sig = commit_signature(user, DateTime.now!("Etc/UTC"))
                commit_committer_sig = commit_author_sig
                commit_message = commit_changeset_message(changeset)
                commit_update_ref = commit_changeset_update_ref(changeset)
                with {:ok, index} <- GitAgent.index(agent),
                      :ok <- GitAgent.index_read_tree(agent, index, tree),
                     {:ok, odb} <- GitAgent.odb(agent),
                     {:ok, blob_oid} <- GitAgent.odb_write(agent, odb, blob_content, :blob),
                      :ok <- GitAgent.index_add(agent, index, blob_oid, blob_path, byte_size(blob_content), 0o100644),
                     {:ok, tree_oid} <- GitAgent.index_write_tree(agent, index),
                     {:ok, old_ref} <- GitAgent.reference(agent, commit_update_ref),
                     {:ok, commit_oid} <- GitAgent.commit_create(agent, commit_update_ref, commit_author_sig, commit_committer_sig, commit_message, tree_oid, [commit.oid]),
                     {:ok, commit} <- GitAgent.object(agent, commit_oid),
                      :ok <- RepoStorage.push_commit(repo, user, {:update, old_ref.oid, commit.oid, commit_update_ref}, commit) do
                  conn
                  |> put_flash(:info, "File #{blob_name} created.")
                  |> redirect(to: Routes.codebase_path(conn, :commit, user_login, repo_name, oid_fmt(commit_oid)))
                end
            end
          else
            conn
            |> put_flash(:error, "Something went wrong! Please check error(s) below.")
            |> put_status(:bad_request)
            |> render("new.html", repo: repo, agent: agent, revision: reference || object, tree: tree, tree_path: tree_path, changeset: %{changeset|action: :insert}, breadcrumb: breadcrumb)
          end
        end
      end || {:error, :unauthorized}
    end || {:error, :not_found}
  end

  @doc """
  Renders a blob edit form.
  """
  def edit(conn, %{"user_login" => user_login, "repo_name" => repo_name, "revision" => revision, "path" => blob_path} = _params) do
    user = current_user(conn)
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: user) do
      if authorized?(user, repo, :write) do
        with {:ok, agent} <- GitAgent.unwrap(repo),
             {:ok, {object, %GitRef{type: :branch, name: branch_name} = reference}} <- GitAgent.revision(agent, revision),
             {:ok, tree_entry} <- GitAgent.tree_entry_by_path(agent, object, Path.join(blob_path)),
             {:ok, %GitBlob{} = blob} <- GitAgent.tree_entry_target(agent, tree_entry),
             {:ok, blob_content} <- GitAgent.blob_content(agent, blob) do
          breadcrumb = %{action: :tree, cwd?: false, tree?: true}
          changeset = blob_commit_changeset(%{name: List.last(blob_path), content: blob_content, branch: branch_name}, %{})
          render(conn, "edit.html", repo: repo, agent: agent, revision: reference, blob: blob, tree_path: blob_path, changeset: changeset, breadcrumb: breadcrumb)
        else
          {:ok, {_object, _reference}} ->
            {:error, :not_found}
          {:ok, %GitTree{}} ->
            {:error, :not_found}
          {:error, reason} ->
            {:error, reason}
        end
      end || {:error, :unauthorized}
    end || {:error, :not_found}
  end

  @doc """
  Updates an existing blob.
  """
  @spec update(Plug.Conn.t, map) :: Plug.Conn.t
  def update(conn, %{"user_login" => user_login, "repo_name" => repo_name, "revision" => revision, "path" => blob_path, "commit" => commit_params} = _params) do
    user = current_user(conn)
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: user) do
      if authorized?(user, repo, :write) do
        with {:ok, agent} <- GitAgent.unwrap(repo),
             {:ok, {object, reference}} <- GitAgent.revision(agent, revision),
             {:ok, commit} <- GitAgent.peel(agent, object, :commit),
             {:ok, tree} <- GitAgent.tree(agent, commit),
             {:ok, tree_entry} <- GitAgent.tree_entry_by_path(agent, object, Path.join(blob_path)),
             {:ok, %GitBlob{} = blob} <- GitAgent.tree_entry_target(agent, tree_entry),
             {:ok, blob_content} <- GitAgent.blob_content(agent, blob) do
          breadcrumb = %{action: :tree, cwd?: false, tree?: true}
          changeset = blob_commit_changeset(%{name: tree_entry.name, content: blob_content}, commit_params)
          if changeset.valid? do # TODO
            blob_content = blob_changeset_content(changeset)
            commit_author_sig = commit_signature(user, DateTime.now!("Etc/UTC"))
            commit_committer_sig = commit_author_sig
            commit_message = commit_changeset_message(changeset)
            commit_update_ref = commit_changeset_update_ref(changeset)
            case Ecto.Changeset.fetch_field(changeset, :name) do
              {:data, blob_name} ->
                with {:ok, index} <- GitAgent.index(agent),
                      :ok <- GitAgent.index_read_tree(agent, index, tree),
                     {:ok, odb} <- GitAgent.odb(agent),
                     {:ok, blob_oid} <- GitAgent.odb_write(agent, odb, blob_content, :blob),
                      :ok <- GitAgent.index_add(agent, index, blob_oid, Path.join(blob_path), byte_size(blob_content), 0o100644),
                     {:ok, tree_oid} <- GitAgent.index_write_tree(agent, index),
                     {:ok, old_ref} <- GitAgent.reference(agent, commit_update_ref),
                     {:ok, commit_oid} <- GitAgent.commit_create(agent, commit_update_ref, commit_author_sig, commit_committer_sig, commit_message, tree_oid, [commit.oid]),
                     {:ok, commit} <- GitAgent.object(agent, commit_oid),
                      :ok <- RepoStorage.push_commit(repo, user, {:update, old_ref.oid, commit.oid, commit_update_ref}, commit) do
                  conn
                  |> put_flash(:info, "File #{blob_name} updated.")
                  |> redirect(to: Routes.codebase_path(conn, :commit, user_login, repo_name, oid_fmt(commit_oid)))
                end
              {:changes, new_name} ->
                changeset = Ecto.Changeset.add_error(changeset, :name, "Cannot rename #{changeset.data.name} to #{new_name}")
                conn
                |> put_flash(:error, "Something went wrong! Please check error(s) below.")
                |> put_status(:bad_request)
                |> render("edit.html", repo: repo, agent: agent, revision: reference || object, blob: blob, tree_path: blob_path, changeset: %{changeset|action: :update}, breadcrumb: breadcrumb)
            end
          else
            conn
            |> put_flash(:error, "Something went wrong! Please check error(s) below.")
            |> put_status(:bad_request)
            |> render("edit.html", repo: repo, agent: agent, revision: reference || object, blob: blob, tree_path: blob_path, changeset: %{changeset|action: :update}, breadcrumb: breadcrumb)
          end
        end
      end || {:error, :unauthorized}
    end || {:error, :not_found}
  end

  @doc """
  Renders a blob delete form.
  """
  def confirm_delete(conn, %{"user_login" => user_login, "repo_name" => repo_name, "revision" => revision, "path" => blob_path} = _params) do
    user = current_user(conn)
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: user) do
      if authorized?(user, repo, :write) do
        with {:ok, agent} <- GitAgent.unwrap(repo),
             {:ok, {object, %GitRef{type: :branch, name: branch_name} = reference}} <- GitAgent.revision(agent, revision),
             {:ok, tree_entry} <- GitAgent.tree_entry_by_path(agent, object, Path.join(blob_path)),
             {:ok, %GitBlob{} = blob} <- GitAgent.tree_entry_target(agent, tree_entry) do
          breadcrumb = %{action: :tree, cwd?: true, tree?: false}
          changeset = commit_changeset(%{branch: branch_name}, %{})
          render(conn, "confirm_delete.html", repo: repo, agent: agent, revision: reference, blob: blob, tree_path: blob_path, changeset: changeset, breadcrumb: breadcrumb)
        else
          {:ok, {_object, _reference}} ->
            {:error, :not_found}
          {:ok, %GitTree{}} ->
            {:error, :not_found}
          {:error, reason} ->
            {:error, reason}
        end
      end || {:error, :unauthorized}
    end || {:error, :not_found}
  end


  @doc """
  Deletes an existing blob.
  """
  @spec delete(Plug.Conn.t, map) :: Plug.Conn.t
  def delete(conn, %{"user_login" => user_login, "repo_name" => repo_name, "revision" => revision, "path" => blob_path, "commit" => commit_params} = _params) do
    user = current_user(conn)
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: user) do
      if authorized?(user, repo, :write) do
        with {:ok, agent} <- GitAgent.unwrap(repo),
             {:ok, {object, reference}} <- GitAgent.revision(agent, revision),
             {:ok, commit} <- GitAgent.peel(agent, object, :commit),
             {:ok, tree} <- GitAgent.tree(agent, commit),
             {:ok, tree_entry} <- GitAgent.tree_entry_by_path(agent, object, Path.join(blob_path)),
             {:ok, %GitBlob{} = blob} <- GitAgent.tree_entry_target(agent, tree_entry) do
          breadcrumb = %{action: :tree, cwd?: true, tree?: false}
          changeset = commit_changeset(%{}, commit_params)
          if changeset.valid? do # TODO
            commit_author_sig = commit_signature(user, DateTime.now!("Etc/UTC"))
            commit_committer_sig = commit_author_sig
            commit_message = commit_changeset_message(changeset)
            commit_update_ref = commit_changeset_update_ref(changeset)
            with {:ok, index} <- GitAgent.index(agent),
                  :ok <- GitAgent.index_read_tree(agent, index, tree),
                  :ok <- GitAgent.index_remove(agent, index, Path.join(blob_path)),
                 {:ok, tree_oid} <- GitAgent.index_write_tree(agent, index),
                 {:ok, old_ref} <- GitAgent.reference(agent, commit_update_ref),
                 {:ok, commit_oid} <- GitAgent.commit_create(agent, commit_update_ref, commit_author_sig, commit_committer_sig, commit_message, tree_oid, [commit.oid]),
                 {:ok, commit} <- GitAgent.object(agent, commit_oid),
                  :ok <- RepoStorage.push_commit(repo, user, {:update, old_ref.oid, commit.oid, commit_update_ref}, commit) do
              conn
              |> put_flash(:info, "File #{List.last(blob_path)} deleted.")
              |> redirect(to: Routes.codebase_path(conn, :commit, user_login, repo_name, oid_fmt(commit_oid)))
            end
          else
            conn
            |> put_flash(:error, "Something went wrong! Please check error(s) below.")
            |> put_status(:bad_request)
            |> render("confirm_delete.html", repo: repo, agent: agent, revision: reference || object, blob: blob, tree_path: blob_path, changeset: %{changeset|action: :delete}, breadcrumb: breadcrumb)
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
      with {:ok, agent} <- GitAgent.unwrap(repo),
           {:ok, head} <- GitAgent.head(agent),
           {:ok, branches} <- GitAgent.branches(agent), do:
        render(conn, "branch_list.html", repo: repo, agent: agent, head: head, branches: Enum.to_list(branches))
    end || {:error, :not_found}
  end

  @doc """
  Renders all tags of a repository.
  """
  @spec tags(Plug.Conn.t, map) :: Plug.Conn.t
  def tags(conn, %{"user_login" => user_login, "repo_name" => repo_name} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      with {:ok, agent} <- GitAgent.unwrap(repo),
           {:ok, tags} <- GitAgent.tags(agent), do:
        render(conn, "tag_list.html", repo: repo, agent: agent, tags: Enum.to_list(tags))
    end || {:error, :not_found}
  end

  @doc """
  Renders a single commit.
  """
  @spec commit(Plug.Conn.t, map) :: Plug.Conn.t
  def commit(conn, %{"user_login" => user_login, "repo_name" => repo_name, "oid" => oid} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      with {:ok, agent} <- GitAgent.unwrap(repo),
           {:ok, object} <- GitAgent.object(agent, oid_parse(oid)),
           {:ok, commit} <- GitAgent.peel(agent, object, :commit),
           {:ok, parents} <- GitAgent.commit_parents(agent, commit),
           {:ok, diff} <- GitAgent.diff(agent, Enum.at(parents, 0), commit), do:
        render(conn, "commit.html", repo: repo, agent: agent, commit: commit, commit_parents: Enum.to_list(parents), diff: diff)
    end || {:error, :not_found}
  end

  @doc """
  Renders all commits for a specific revision.
  """
  @spec history(Plug.Conn.t, map) :: Plug.Conn.t
  def history(conn, %{"user_login" => user_login, "repo_name" => repo_name, "revision" => revision, "path" => []} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      with {:ok, agent} <- GitAgent.unwrap(repo),
           {:ok, {object, reference}} <- GitAgent.revision(agent, revision),
           {:ok, history} <- GitAgent.history(agent, object) do
        breadcrumb = %{action: :history, cwd?: true, tree?: true}
        render(conn, "commit_list.html", repo: repo, agent: agent, revision: reference || object, commits: history, tree_path: [], breadcrumb: breadcrumb)
      end
    end || {:error, :not_found}
  end

  def history(conn, %{"user_login" => user_login, "repo_name" => repo_name, "revision" => revision, "path" => tree_path} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      with {:ok, agent} <- GitAgent.unwrap(repo),
           {:ok, {object, reference}} <- GitAgent.revision(agent, revision),
           {:ok, tree} <- GitAgent.tree(agent, revision),
           {:ok, tree_entry} <- GitAgent.tree_entry_by_path(agent, tree, Path.join(tree_path)),
           {:ok, history} <- GitAgent.history(agent, object, pathspec: Path.join(tree_path)) do
        breadcrumb = %{action: :history, cwd?: true, tree?: tree_entry.type == :tree}
        render(conn, "commit_list.html", repo: repo, agent: agent, revision: reference || object, commits: history, tree_path: tree_path, breadcrumb: breadcrumb)
      end
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
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn), preload: :contributors) do
      with {:ok, agent} <- GitAgent.unwrap(repo),
           {:ok, {object, reference}} <- GitAgent.revision(agent, revision),
           {:ok, commit} <- GitAgent.peel(agent, object, :commit),
           {:ok, tree} <- GitAgent.tree(agent, object),
           {:ok, tree_entries} <- GitAgent.tree_entries(agent, tree) do
        render(conn, "show.html",
          breadcrumb: %{action: :tree, cwd?: true, tree?: true},
          repo: repo,
          revision: reference || object,
          commit: commit,
          tree: tree,
          tree_entries: tree_entries,
          tree_path: [],
          stats: stats(repo, agent, reference || object)
        )
      end
    end || {:error, :not_found}
  end

  def tree(conn, %{"user_login" => user_login, "repo_name" => repo_name, "revision" => revision, "path" => tree_path} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      with {:ok, agent} <- GitAgent.unwrap(repo),
           {:ok, {object, reference}} <- GitAgent.revision(agent, revision),
           {:ok, commit} <- GitAgent.peel(agent, object, :commit),
           {:ok, tree_entry} <- GitAgent.tree_entry_by_path(agent, object, Path.join(tree_path)),
           {:ok, %GitTree{} = tree} <- GitAgent.tree_entry_target(agent, tree_entry),
           {:ok, tree_entries} <- GitAgent.tree_entries(agent, tree) do
        render(conn, "tree.html",
          breadcrumb: %{action: :tree, cwd?: true, tree?: true},
          repo: repo,
          revision: reference || object,
          commit: commit,
          tree: tree,
          tree_entries: tree_entries,
          tree_path: tree_path
        )
      else
        {:ok, %GitBlob{}} ->
          redirect(conn, to: Routes.codebase_path(conn, :blob, repo.owner, repo, revision, tree_path))
        {:error, reason} ->
          {:error, reason}
      end
    end || {:error, :not_found}
  end

  @doc """
  Renders a blob for a specific revision and path.
  """
  @spec blob(Plug.Conn.t, map) :: Plug.Conn.t
  def blob(conn, %{"user_login" => user_login, "repo_name" => repo_name, "revision" => revision, "path" => blob_path} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      with {:ok, agent} <- GitAgent.unwrap(repo),
           {:ok, {object, reference}} <- GitAgent.revision(agent, revision),
           {:ok, commit} <- GitAgent.peel(agent, object, :commit),
           {:ok, tree_entry} <- GitAgent.tree_entry_by_path(agent, object, Path.join(blob_path)),
           {:ok, %GitBlob{} = blob} <- GitAgent.tree_entry_target(agent, tree_entry),
           {:ok, blob_content} <- GitAgent.blob_content(agent, blob),
           {:ok, blob_size} <- GitAgent.blob_size(agent, blob) do
        render(conn, "blob.html",
          breadcrumb: %{action: :tree, cwd?: true, tree?: false},
          repo: repo,
          revision: reference || object,
          commit: commit,
          blob_content: blob_content,
          blob_size: blob_size,
          tree_path: blob_path
        )
      else
        {:ok, %GitTree{}} ->
          redirect(conn, to: Routes.codebase_path(conn, :tree, repo.owner, repo, revision, blob_path))
        {:error, reason} ->
          {:error, reason}
      end
    end || {:error, :not_found}
  end

  #
  # Helpers
  #


  defp blob_changeset(blob, params) do
    types = %{name: :string, content: :string}
    {blob, types}
    |> Ecto.Changeset.cast(params, Map.keys(types))
    |> Ecto.Changeset.validate_required([:name, :content])
  end

  defp blob_changeset_name(changeset), do: Ecto.Changeset.fetch_field!(changeset, :name)

  defp blob_changeset_content(changeset), do: Ecto.Changeset.fetch_field!(changeset, :content)

  defp commit_signature(user, timestamp) do
    user = DB.preload(user, :primary_email)
    %{name: user.name, email: user.primary_email.address, timestamp: timestamp}
  end

  defp commit_changeset(commit, params) do
    types = %{message: :string, description: :string, branch: :string}
    {commit, types}
    |> Ecto.Changeset.cast(params, Map.keys(types))
    |> Ecto.Changeset.validate_required([:message, :branch])
  end

  defp commit_changeset_message(changeset) do
    message_title = Ecto.Changeset.fetch_field!(changeset, :message)
    if message_body = Ecto.Changeset.get_field(changeset, :description),
      do: message_title <> "\n\n" <> message_body,
    else: message_title
  end

  defp commit_changeset_update_ref(changeset), do: "refs/heads/" <> Ecto.Changeset.fetch_field!(changeset, :branch)

  defp blob_commit_changeset(blob_commit, params) do
    Ecto.Changeset.merge(blob_changeset(blob_commit, params), commit_changeset(blob_commit, params))
  end

  defp stats(repo, agent, revision) do
    with {:ok, branches} <- GitAgent.branches(agent),
         {:ok, tags} <- GitAgent.tags(agent),
         {:ok, history_count} <- GitAgent.history_count(agent, revision) do
      %{branches: Enum.count(branches), tags: Enum.count(tags), commits: history_count, contributors: RepoQuery.count_contributors(repo)}
    else
      {:error, _reason} ->
        %{commits: 0, branches: 0, tags: 0, contributors: 0}
    end
  end
end
