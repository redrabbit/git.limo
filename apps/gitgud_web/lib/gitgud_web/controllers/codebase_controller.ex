defmodule GitGud.Web.CodebaseController do
  @moduledoc """
  Module responsible for CRUD actions on `GitGud.Repo`.
  """

  use GitGud.Web, :controller

  alias GitGud.DB
  alias GitGud.User
  alias GitGud.UserQuery
  alias GitGud.Repo
  alias GitGud.RepoQuery
  alias GitGud.RepoStats
  alias GitGud.RepoStorage
  alias GitGud.ReviewQuery
  alias GitGud.GPGKey

  alias GitRekt.GitAgent
  alias GitRekt.{GitRef, GitTag, GitBlob, GitTree, GitTreeEntry}

  require Logger

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
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: user, preload: :stats) do
      with {:ok, agent} <- GitAgent.unwrap(repo),
           {:ok, false} <- GitAgent.empty?(agent),
           {:ok, head} <- GitAgent.head(agent),
           {:ok, commit} <- GitAgent.peel(agent, head, :commit),
           {:ok, commit_info} <- GitAgent.transaction(agent, {:commit_info, commit.oid}, &resolve_commit_info(&1, commit)),
           {:ok, tree} <- GitAgent.tree(agent, commit),
           {:ok, tree_entries} <- GitAgent.tree_entries(agent, tree) do
        tree_entries = Enum.to_list(tree_entries)
        render(conn, "show.html",
          breadcrumb: %{action: :tree, cwd?: true, tree?: true},
          repo: repo,
          revision: head,
          commit: commit,
          commit_info: resolve_db_commit_info(commit_info),
          tree_path: [],
          tree_entries: tree_entries,
          tree_readme: Enum.find_value(tree_entries, &tree_readme(agent, &1)),
          stats: stats(repo, agent, head)
        )
      else
        {:ok, true} ->
          render(conn, "initialize.html", repo: repo)
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
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: user) do
      if authorized?(user, repo, :push) do
        with {:ok, agent} <- GitAgent.unwrap(repo),
             {:ok, {_object, %GitRef{type: :branch, name: branch_name} = reference}} <- GitAgent.revision(agent, revision) do
          render(conn, "new.html",
            breadcrumb: %{action: :tree, cwd?: true, tree?: true},
            changeset: blob_commit_changeset(%{branch: branch_name}, %{}),
            repo: repo,
            revision: reference,
            tree_path: []
          )
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
      if authorized?(user, repo, :push) do
        with {:ok, agent} <- GitAgent.unwrap(repo),
             {:ok, {object, %GitRef{type: :branch, name: branch_name} = reference}} <- GitAgent.revision(agent, revision),
             {:ok, %GitTreeEntry{type: :tree}} <- GitAgent.tree_entry_by_path(agent, object, Path.join(tree_path)) do
          render(conn, "new.html",
            breadcrumb: %{action: :tree, cwd?: true, tree?: true},
            changeset: blob_commit_changeset(%{branch: branch_name}, %{}),
            repo: repo,
            revision: reference,
            tree_path: tree_path
          )
        else
          {:ok, {_object, _reference}} ->
            {:error, :not_found}
          {:ok, %GitTreeEntry{type: :blob}} ->
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
      if authorized?(user, repo, :push) do
        with {:ok, agent} <- GitAgent.unwrap(repo),
             {:ok, {object, reference}} <- GitAgent.revision(agent, revision),
             {:ok, commit} <- GitAgent.peel(agent, object, :commit),
             {:ok, tree} <- GitAgent.tree(agent, commit) do
          breadcrumb = %{action: :tree, cwd?: true, tree?: true}
          changeset = blob_commit_changeset(%{}, commit_params)
          if changeset.valid? do # TODO
            blob_name = blob_changeset_name(changeset)
            blob_path = tree_path ++ [blob_name]
            case GitAgent.tree_entry_by_path(agent, tree, Path.join(blob_path)) do
              {:ok, _tree_entry} ->
                changeset = Ecto.Changeset.add_error(changeset, :name, "has already been taken")
                conn
                |> put_flash(:error, "Something went wrong! Please check error(s) below.")
                |> put_status(:bad_request)
                |> render("new.html", breadcrumb: breadcrumb, changeset: %{changeset|action: :insert}, repo: repo, revision: reference || object, tree_path: tree_path)
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
                      :ok <- GitAgent.index_add(agent, index, blob_oid, Path.join(blob_path), byte_size(blob_content), 0o100644),
                     {:ok, tree_oid} <- GitAgent.index_write_tree(agent, index),
                     {:ok, old_ref} <- GitAgent.reference(agent, commit_update_ref),
                     {:ok, commit_oid} <- GitAgent.commit_create(agent, commit_update_ref, commit_author_sig, commit_committer_sig, commit_message, tree_oid, [commit.oid]),
                     {:ok, commit} <- GitAgent.object(agent, commit_oid),
                      :ok <- RepoStorage.push_meta(repo, user, agent, [{:update, old_ref.oid, commit.oid, commit_update_ref}], [{commit_oid, commit}]) do
                  conn
                  |> put_flash(:info, "File #{blob_name} created.")
                  |> redirect(to: Routes.codebase_path(conn, :blob, user_login, repo_name, Path.basename(commit_update_ref), blob_path))
                end
            end
          else
            conn
            |> put_flash(:error, "Something went wrong! Please check error(s) below.")
            |> put_status(:bad_request)
            |> render("new.html", breadcrumb: breadcrumb, changeset: %{changeset|action: :insert}, repo: repo, revision: reference || object, tree_path: tree_path)
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
      if authorized?(user, repo, :push) do
        with {:ok, agent} <- GitAgent.unwrap(repo),
             {:ok, {object, %GitRef{type: :branch, name: branch_name} = reference}} <- GitAgent.revision(agent, revision),
             {:ok, tree_entry} <- GitAgent.tree_entry_by_path(agent, object, Path.join(blob_path)),
             {:ok, %GitBlob{} = blob} <- GitAgent.tree_entry_target(agent, tree_entry),
             {:ok, blob_content} <- GitAgent.blob_content(agent, blob) do
          render(conn, "edit.html",
            breadcrumb: %{action: :tree, cwd?: false, tree?: true},
            changeset: blob_commit_changeset(%{name: List.last(blob_path), content: blob_content, branch: branch_name}, %{}),
            repo: repo,
            revision: reference,
            tree_path: blob_path
         )
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
      if authorized?(user, repo, :push) do
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
                      :ok <- RepoStorage.push_meta(repo, user, agent, [{:update, old_ref.oid, commit.oid, commit_update_ref}], [{commit_oid, commit}]) do
                  conn
                  |> put_flash(:info, "File #{blob_name} updated.")
                  |> redirect(to: Routes.codebase_path(conn, :blob, user_login, repo_name, Path.basename(commit_update_ref), blob_path))
                end
              {:changes, new_name} ->
                changeset = Ecto.Changeset.add_error(changeset, :name, "Cannot rename #{changeset.data.name} to #{new_name}")
                conn
                |> put_flash(:error, "Something went wrong! Please check error(s) below.")
                |> put_status(:bad_request)
                |> render("edit.html", breadcrumb: breadcrumb, changeset: %{changeset|action: :update}, repo: repo, revision: reference || object, tree_path: blob_path)
            end
          else
            conn
            |> put_flash(:error, "Something went wrong! Please check error(s) below.")
            |> put_status(:bad_request)
            |> render("edit.html", breadcrumb: breadcrumb, changeset: %{changeset|action: :update}, repo: repo, revision: reference || object, tree_path: blob_path)
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
      if authorized?(user, repo, :push) do
        with {:ok, agent} <- GitAgent.unwrap(repo),
             {:ok, {object, %GitRef{type: :branch, name: branch_name} = reference}} <- GitAgent.revision(agent, revision),
             {:ok, %GitTreeEntry{type: :blob}} <- GitAgent.tree_entry_by_path(agent, object, Path.join(blob_path)) do
          render(conn, "confirm_delete.html",
            breadcrumb: %{action: :tree, cwd?: true, tree?: false},
            changeset: commit_changeset(%{branch: branch_name}, %{}),
            repo: repo,
            revision: reference,
            tree_path: blob_path
          )
        else
          {:ok, {_object, _reference}} ->
            {:error, :not_found}
          {:ok, %GitTreeEntry{type: :tree}} ->
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
      if authorized?(user, repo, :push) do
        with {:ok, agent} <- GitAgent.unwrap(repo),
             {:ok, {object, reference}} <- GitAgent.revision(agent, revision),
             {:ok, commit} <- GitAgent.peel(agent, object, :commit),
             {:ok, tree} <- GitAgent.tree(agent, commit),
             {:ok, %GitTreeEntry{type: :blob}} <- GitAgent.tree_entry_by_path(agent, object, Path.join(blob_path)) do
          breadcrumb = %{action: :tree, cwd?: true, tree?: false}
          changeset = commit_changeset(%{}, commit_params)
          if changeset.valid? do # TODO
            tree_path = Enum.drop(blob_path, -1)
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
                  :ok <- RepoStorage.push_meta(repo, user, agent, [{:update, old_ref.oid, commit_oid, commit_update_ref}], [{commit_oid, commit}]) do
              conn
              |> put_flash(:info, "File #{List.last(blob_path)} deleted.")
              |> redirect(to: Routes.codebase_path(conn, :tree, user_login, repo_name, Path.basename(commit_update_ref), tree_path))
            end
          else
            conn
            |> put_flash(:error, "Something went wrong! Please check error(s) below.")
            |> put_status(:bad_request)
            |> render("confirm_delete.html", breadcrumb: breadcrumb, repo: repo, revision: reference || object, tree_path: blob_path, changeset: %{changeset|action: :delete})
          end
        else
          {:ok, %GitTreeEntry{type: :tree}} ->
            {:error, :not_found}
          {:error, reason} ->
            {:error, reason}
        end
      end || {:error, :unauthorized}
    end || {:error, :not_found}
  end

  @doc """
  Renders a single commit.
  """
  @spec commit(Plug.Conn.t, map) :: Plug.Conn.t
  def commit(conn, %{"user_login" => user_login, "repo_name" => repo_name, "oid" => oid} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      with {:ok, agent} <- GitAgent.unwrap(repo),
           {:ok, commit} <- GitAgent.object(agent, oid_parse(oid)),
           {:ok, commit_info} <- GitAgent.transaction(agent, {:commit_info, commit.oid}, &resolve_commit_info(&1, commit)),
           {:ok, diff} <- GitAgent.diff(agent, hd(commit_info.parents), commit), # TODO
           {:ok, diff_stats} <- GitAgent.diff_stats(agent, diff),
           {:ok, diff_deltas} <- GitAgent.diff_deltas(agent, diff) do
        render(conn, "commit.html",
          repo: repo,
          comment_count: ReviewQuery.commit_comment_count(repo, commit),
          commit: commit,
          commit_info: resolve_db_commit_info(commit_info),
          diff_stats: diff_stats,
          diff_deltas: diff_deltas,
          reviews: ReviewQuery.commit_line_reviews(repo, commit)
        )
      end
    end || {:error, :not_found}
  end

  @doc """
  Renders a tree for a specific revision and path.
  """
  @spec tree(Plug.Conn.t, map) :: Plug.Conn.t
  def tree(conn, %{"user_login" => user_login, "repo_name" => repo_name, "revision" => revision, "path" => []} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn), preload: :stats) do
      with {:ok, agent} <- GitAgent.unwrap(repo),
           {:ok, {object, reference}} <- GitAgent.revision(agent, revision),
           {:ok, commit} <- GitAgent.peel(agent, object, :commit),
           {:ok, commit_info} <- GitAgent.transaction(agent, {:commit_info, commit.oid}, &resolve_commit_info(&1, commit)),
           {:ok, tree} <- GitAgent.tree(agent, object),
           {:ok, tree_entries} <- GitAgent.tree_entries(agent, tree) do
        tree_entries = Enum.to_list(tree_entries)
        render(conn, "show.html",
          breadcrumb: %{action: :tree, cwd?: true, tree?: true},
          repo: repo,
          commit: commit,
          commit_info: resolve_db_commit_info(commit_info),
          revision: reference || object,
          tree_path: [],
          tree_entries: tree_entries,
          tree_readme: Enum.find_value(tree_entries, &tree_readme(agent, &1)),
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
        tree_entries = Enum.to_list(tree_entries)
        render(conn, "tree.html",
          breadcrumb: %{action: :tree, cwd?: true, tree?: true},
          repo: repo,
          revision: reference || object,
          commit: commit,
          tree_path: tree_path,
          tree_entries: tree_entries,
          tree_readme: Enum.find_value(tree_entries, &tree_readme(agent, &1))
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

  @doc """
  Renders all branches of a repository.
  """
  @spec branches(Plug.Conn.t, map) :: Plug.Conn.t
  def branches(conn, %{"user_login" => user_login, "repo_name" => repo_name} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      with {:ok, agent} <- GitAgent.unwrap(repo),
           {:ok, head} <- GitAgent.head(agent),
           {:ok, branches} <- GitAgent.branches(agent),
           {:ok, branches_authors} <- resolve_revisions_authors(agent, Enum.to_list(branches)) do
        page = paginate(conn, Enum.sort_by(branches_authors, &elem(&1, 2), &>=/2))
        branches_authors = resolve_revisions_authors_db(page.slice)
        render(conn, "branch_list.html", repo: repo, head: head, page: %{page|slice: branches_authors})
      end
    end || {:error, :not_found}
  end

  @doc """
  Renders all tags of a repository.
  """
  @spec tags(Plug.Conn.t, map) :: Plug.Conn.t
  def tags(conn, %{"user_login" => user_login, "repo_name" => repo_name} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      with {:ok, agent} <- GitAgent.unwrap(repo),
           {:ok, tags} <- GitAgent.tags(agent) do
        page = paginate(conn, Enum.reverse(tags))
        case resolve_revisions_authors(agent, page.slice) do
          {:ok, tags_authors} ->
            tags_authors = resolve_revisions_authors_db(tags_authors)
            render(conn, "tag_list.html", repo: repo, page: %{page|slice: tags_authors})
          {:error, reason} ->
            {:error, reason}
        end
      end
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
        page = paginate_cursor(conn, history, &(oid_fmt(&1.oid) == &2), &oid_fmt(&1.oid))
        case resolve_commits_infos(agent, page.slice) do
          {:ok, commits_infos} ->
            commits_infos = resolve_commits_info_db(repo, commits_infos)
            render(conn, "commit_list.html",
              breadcrumb: %{action: :history, cwd?: true, tree?: true},
              repo: repo,
              revision: reference || object,
              page: %{page|slice: commits_infos},
              tree_path: []
            )
          {:error, reason} ->
            {:error, reason}
        end
      end
    end || {:error, :not_found}
  end

  def history(conn, %{"user_login" => user_login, "repo_name" => repo_name, "revision" => revision, "path" => tree_path} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      with {:ok, agent} <- GitAgent.unwrap(repo),
           {:ok, {object, reference}} <- GitAgent.revision(agent, revision),
           {:ok, history} <- GitAgent.history(agent, object, pathspec: Path.join(tree_path)) do
        page = paginate_cursor(conn, history, &(oid_fmt(&1.oid) == &2), &oid_fmt(&1.oid))
        if tree_entry = Enum.find_value(page.slice, &commit_tree_entry(agent, &1, tree_path)) do
          case resolve_commits_infos(agent, page.slice) do
            {:ok, commits_infos} ->
              commits_infos = resolve_commits_info_db(repo, commits_infos)
              render(conn, "commit_list.html",
                breadcrumb: %{action: :history, cwd?: true, tree?: tree_entry.type == :tree},
                repo: repo,
                revision: reference || object,
                page: %{page|slice: commits_infos},
                tree_path: tree_path
              )
            {:error, reason} ->
              {:error, reason}
          end
        end
      end
    end || {:error, :not_found}
  end

  def history(conn, %{"user_login" => user_login, "repo_name" => repo_name} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      with {:ok, agent} <- GitAgent.unwrap(repo),
           {:ok, head} <- GitAgent.head(agent),
           {:ok, history} <- GitAgent.history(agent, head) do
        page = paginate_cursor(conn, history, &(oid_fmt(&1.oid) == &2), &oid_fmt(&1.oid))
        case resolve_commits_infos(agent, page.slice) do
          {:ok, commits_infos} ->
            commits_infos = resolve_commits_info_db(repo, commits_infos)
            render(conn, "commit_list.html",
              breadcrumb: %{action: :history, cwd?: true, tree?: true},
              repo: repo,
              revision: head,
              page: %{page|slice: commits_infos},
              tree_path: []
            )
          {:error, reason} ->
            {:error, reason}
        end
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

  defp blob_commit_changeset(blob_commit, params) do
    Ecto.Changeset.merge(blob_changeset(blob_commit, params), commit_changeset(blob_commit, params))
  end

  defp blob_changeset_name(changeset), do: Ecto.Changeset.fetch_field!(changeset, :name)

  defp blob_changeset_content(changeset), do: Ecto.Changeset.fetch_field!(changeset, :content)

  defp tree_readme(agent, %GitTreeEntry{type: :blob, name: "README.md" = name} = tree_entry) do
    {:ok, blob} = GitAgent.tree_entry_target(agent, tree_entry)
    {:ok, blob_content} = GitAgent.blob_content(agent, blob)
    {GitGud.Web.Markdown.markdown_safe(blob_content), name}
  end

  defp tree_readme(agent, %GitTreeEntry{type: :blob, name: "README" = name} = tree_entry) do
    {:ok, blob} = GitAgent.tree_entry_target(agent, tree_entry)
    {:ok, blob_content} = GitAgent.blob_content(agent, blob)
    {blob_content, name}
  end

  defp tree_readme(_agent, %GitTreeEntry{}), do: nil

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

  defp commit_tree_entry(agent, commit, tree_path) do
    case GitAgent.tree_entry_by_path(agent, commit, Path.join(tree_path)) do
      {:ok, tree_entry} ->
        tree_entry
      {:error, _reason} ->
        nil
    end
  end

  defp resolve_commits_infos(agent, commits) do
    GitAgent.transaction(agent, fn agent ->
      Enum.reduce_while(Enum.reverse(commits), {:ok, []}, &resolve_commit_info(agent, &1, &2))
    end)
  end

  defp resolve_commits_info_db(repo, commits_infos) do
    {commits, infos} = Enum.unzip(commits_infos)
    users = UserQuery.by_email(Enum.uniq(Enum.flat_map(infos, &[&1.author.email, &1.committer.email])), preload: [:emails, :gpg_keys])
    count = Map.new(ReviewQuery.commit_comment_count(repo, commits))
    Enum.map(commits_infos, fn {commit, commit_info} ->
      author = resolve_db_user(commit_info.author, users)
      committer = resolve_db_user(commit_info.committer, users)
      gpg_key = resolve_db_user_gpg_key(commit_info.gpg_sig, committer)
      {commit, Map.merge(commit_info, %{author: author, committer: committer, gpg_key: gpg_key}), Map.get(count, commit.oid, 0)}
    end)
  end

  defp resolve_commit_info(agent, commit, {:ok, acc}) do
    case GitAgent.transaction(agent, {:commit_info, commit.oid}, &resolve_commit_info(&1, commit)) do
         {:ok, commit_info} ->
            {:cont, {:ok, [{commit, commit_info}|acc]}}
        {:error, reason} ->
          {:halt, {:error, reason}}
    end
  end

  defp resolve_commit_info(agent, commit) do
    with {:ok, timestamp} <- GitAgent.commit_timestamp(agent, commit),
         {:ok, message} <- GitAgent.commit_message(agent, commit),
         {:ok, author} <- GitAgent.commit_author(agent, commit),
         {:ok, committer} <- GitAgent.commit_committer(agent, commit),
         {:ok, parents} <- GitAgent.commit_parents(agent, commit) do
      gpg_sig =
        case GitAgent.commit_gpg_signature(agent, commit) do
          {:ok, gpg_sig} -> gpg_sig
          {:error, _reason} -> nil
        end
      {:ok, %{
        author: author,
        committer: committer,
        message: message,
        timestamp: timestamp,
        gpg_sig: gpg_sig,
        parents: Enum.to_list(parents)}
      }
    end
  end

  defp resolve_revisions_authors(agent, revs) do
    GitAgent.transaction(agent, fn agent ->
      Enum.reduce_while(Enum.reverse(revs), {:ok, []}, &resolve_revision_author(agent, &1, &2))
    end)
  end

  defp resolve_revisions_authors_db(revs_authors) do
    users = UserQuery.by_email(Enum.uniq(Enum.map(revs_authors, &(elem(&1, 1).email))), preload: :emails)
    Enum.map(revs_authors, fn {rev, author, timestamp} ->
      {rev, resolve_db_user(author, users), timestamp}
    end)
  end

  defp resolve_revision_author(agent, %GitRef{} = rev, {:ok, acc}) do
    with {:ok, commit} <- GitAgent.peel(agent, rev, :commit),
         {:ok, author} <- GitAgent.commit_author(agent, commit) do
      {:cont, {:ok, [{rev, author, author.timestamp}|acc]}}
    else
      {:error, reason} ->
        {:halt, {:error, reason}}
    end
  end

  defp resolve_revision_author(agent, %GitTag{} = tag, {:ok, acc}) do
    case GitAgent.tag_author(agent, tag) do
      {:ok, author} ->
        {:cont, {:ok, [{tag, author, author.timestamp}|acc]}}
      {:error, reason} ->
        {:halt, {:error, reason}}
    end
  end

  defp resolve_db_commit_info(commit_info) do
    users = UserQuery.by_email(Enum.uniq([commit_info.author.email, commit_info.committer.email]), preload: [:emails, :gpg_keys])
    author = resolve_db_user(commit_info.author, users)
    committer = resolve_db_user(commit_info.committer, users)
    gpg_key = resolve_db_user_gpg_key(commit_info.gpg_sig, committer)
    Map.merge(commit_info, %{author: author, committer: committer, gpg_key: gpg_key})
  end

  defp resolve_db_user(%{email: email} = map, users) do
    Enum.find(users, map, fn user -> email in Enum.map(user.emails, &(&1.address)) end)
  end

  defp resolve_db_user_gpg_key(gpg_sig, %User{} = user) when not is_nil(gpg_sig) do
    gpg_key_id =
      gpg_sig
      |> GPGKey.decode!()
      |> GPGKey.parse!()
      |> get_in([:sig, :sub_pack, :issuer])
    Enum.find(user.gpg_keys, &String.ends_with?(&1.key_id, gpg_key_id))
  end

  defp resolve_db_user_gpg_key(_gpg_sig, _user), do: nil

  defp stats(%Repo{stats: %RepoStats{refs: stats_refs}} = repo, agent, revision) when is_map(stats_refs) do
    rev_stats =
      case revision do
        %GitRef{} = ref ->
          Map.get(stats_refs, to_string(ref), %{})
        rev ->
          case GitAgent.history_count(agent, rev) do
            {:ok, commit_count} -> %{"count" => commit_count}
            {:error, _reason} -> %{}
          end
      end
    rev_groups = Enum.group_by(stats_refs, fn {"refs/" <> ref_name_suffix, _stats} -> hd(Path.split(ref_name_suffix)) end)
    %{
      branches: Enum.count(Map.get(rev_groups, "heads", [])),
      tags: Enum.count(Map.get(rev_groups, "tags", [])),
      commits: rev_stats["count"] || 0,
      contributors: RepoQuery.count_contributors(repo)
    }
  end

  defp stats(%Repo{} = repo, agent, revision) do
    Logger.warn("repository #{repo.owner.login}/#{repo.name} does not have stats")
    with {:ok, branches} <- GitAgent.branches(agent),
         {:ok, tags} <- GitAgent.tags(agent),
         {:ok, commit_count} <- GitAgent.history_count(agent, revision) do
      %{
        branches: Enum.count(branches),
        tags: Enum.count(tags),
        commits: commit_count,
        contributors: RepoQuery.count_contributors(repo)
      }
    else
      {:error, _reason} ->
        %{commits: 0, branches: 0, tags: 0, contributors: 0}
    end
  end
end
