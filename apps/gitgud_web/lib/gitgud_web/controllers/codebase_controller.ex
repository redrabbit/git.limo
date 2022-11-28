defmodule GitGud.Web.CodebaseController do
  @moduledoc """
  Module responsible for CRUD actions on `GitGud.Repo`.
  """

  use GitGud.Web, :controller

  alias GitRekt.GitAgent
  alias GitRekt.GitRepo
  alias GitRekt.GitRef
  alias GitRekt.GitTag

  alias GitGud.DB
  alias GitGud.UserQuery
  alias GitGud.RepoQuery
  alias GitGud.IssueQuery

  plug :put_layout, :repo
  plug :ensure_authenticated when action in [:new, :create, :edit, :update, :confirm_delete, :delete]

  action_fallback GitGud.Web.FallbackController

  @doc """
  Renders a blob creation form.
  """
  def new(conn, %{"user_login" => user_login, "repo_name" => repo_name, "revision" => revision, "path" => tree_path} = _params) do
    user = current_user(conn)
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: user) do
      if authorized?(user, repo, :push) do
        with {:ok, agent} <- GitRepo.get_agent(repo),
             {:ok, {reference, commit, _tree}} <- GitAgent.transaction(agent, &resolve_tree(&1, revision, tree_path)) do
          render(conn, "new.html",
            repo: repo,
            repo_open_issue_count: IssueQuery.count_repo_issues(repo, status: :open),
            agent: agent,
            revision: reference,
            commit: commit,
            tree_path: tree_path,
            breadcrumb: %{action: :new, cwd?: true, tree?: true},
            changeset: blob_commit_changeset(%{branch: reference.name}, %{})
          )
        end
      end || {:error, :forbidden}
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
        with {:ok, agent} <- GitRepo.get_agent(repo),
             {:ok, {reference, commit, tree}} <- GitAgent.transaction(agent, &resolve_tree(&1, revision, tree_path)) do
          breadcrumb = %{action: :new, cwd?: true, tree?: true}
          changeset = blob_commit_changeset(%{}, commit_params)
          if changeset.valid? do # TODO
            blob_name = blob_changeset_name(changeset)
            blob_path = tree_path ++ [blob_name]
            blob_content = blob_changeset_content(changeset)
            commit_author_sig = commit_signature(user, DateTime.now!("Etc/UTC"))
            commit_committer_sig = commit_author_sig
            commit_message = commit_changeset_message(changeset)
            commit_update_ref = commit_changeset_update_ref(changeset)
            with {:ok, {reference_oid, commit_oid}} <-GitAgent.transaction(agent, &write_blob_new(&1, commit, tree, blob_path, blob_content, commit_update_ref, commit_author_sig, commit_committer_sig, commit_message)),
                 {:ok, repo} <- GitRepo.push(repo, [{:update, reference_oid, commit_oid, commit_update_ref}]) do
              conn
              |> put_flash(:info, "File #{blob_name} created.")
              |> redirect(to: Routes.codebase_path(conn, :blob, user_login, repo.name, Path.basename(commit_update_ref), blob_path))
            else
              {:error, {:already_exist, _tree_entry}} ->
                changeset = Ecto.Changeset.add_error(changeset, :name, "has already been taken")
                conn = put_flash(conn, :error, "Something went wrong! Please check error(s) below.")
                conn = put_status(conn, :bad_request)
                render(conn, "new.html",
                  repo: repo,
                  repo_open_issue_count: IssueQuery.count_repo_issues(repo, status: :open),
                  agent: agent,
                  revision: reference || commit,
                  commit: commit,
                  tree_path: tree_path,
                  breadcrumb: breadcrumb,
                  changeset: %{changeset|action: :insert}
                )
              {:error, reason} ->
                {:error, reason}
            end
          else
            conn = put_flash(conn, :error, "Something went wrong! Please check error(s) below.")
            conn = put_status(conn, :bad_request)
            render(conn, "new.html",
              repo: repo,
              repo_open_issue_count: IssueQuery.count_repo_issues(repo, status: :open),
              agent: agent,
              revision: reference || commit,
              commit: commit,
              tree_path: tree_path,
              breadcrumb: breadcrumb,
              changeset: %{changeset|action: :insert}
            )
          end
        end
      end || {:error, :forbidden}
    end || {:error, :not_found}
  end

  @doc """
  Renders a blob edit form.
  """
  def edit(conn, %{"user_login" => user_login, "repo_name" => repo_name, "revision" => revision, "path" => blob_path} = _params) do
    unless Enum.empty?(blob_path) do
      user = current_user(conn)
      if repo = RepoQuery.user_repo(user_login, repo_name, viewer: user) do
        if authorized?(user, repo, :push) do
          with {:ok, agent} <- GitRepo.get_agent(repo),
               {:ok, {reference, commit, blob_content, _blob_size}} <- GitAgent.transaction(agent, &resolve_blob(&1, revision, blob_path)) do
            render(conn, "edit.html",
              repo: repo,
              repo_open_issue_count: IssueQuery.count_repo_issues(repo, status: :open),
              agent: agent,
              revision: reference,
              commit: commit,
              tree_path: blob_path,
              breadcrumb: %{action: :tree, cwd?: false, tree?: true},
              changeset: blob_commit_changeset(%{name: List.last(blob_path), content: blob_content, branch: reference.name}, %{})
            )
          end
        end || {:error, :forbidden}
      end
    end || {:error, :not_found}
  end

  @doc """
  Updates an existing blob.
  """
  @spec update(Plug.Conn.t, map) :: Plug.Conn.t
  def update(conn, %{"user_login" => user_login, "repo_name" => repo_name, "revision" => revision, "path" => blob_path, "commit" => commit_params} = _params) do
    unless Enum.empty?(blob_path) do
      user = current_user(conn)
      if repo = RepoQuery.user_repo(user_login, repo_name, viewer: user) do
        if authorized?(user, repo, :push) do
          with {:ok, agent} <- GitRepo.get_agent(repo),
               {:ok, {reference, commit, blob_content, _blob_size}} <- GitAgent.transaction(agent, &resolve_blob(&1, revision, blob_path)) do
            breadcrumb = %{action: :tree, cwd?: false, tree?: true}
            changeset = blob_commit_changeset(%{name: Path.basename(blob_path), content: blob_content}, commit_params)
            if changeset.valid? do # TODO
              blob_content = blob_changeset_content(changeset)
              commit_update_ref = commit_changeset_update_ref(changeset)
              commit_author_sig = commit_signature(user, DateTime.now!("Etc/UTC"))
              commit_committer_sig = commit_author_sig
              commit_message = commit_changeset_message(changeset)
              case Ecto.Changeset.fetch_field(changeset, :name) do
                {:data, blob_name} ->
                  with {:ok, {reference_oid, commit_oid}} = GitAgent.transaction(agent, &write_blob(&1, commit, blob_path, blob_content, commit_update_ref, commit_author_sig, commit_committer_sig, commit_message)),
                       {:ok, repo} <- GitRepo.push(repo, [{:update, reference_oid, commit_oid, commit_update_ref}]) do
                    conn
                    |> put_flash(:info, "File #{blob_name} updated.")
                    |> redirect(to: Routes.codebase_path(conn, :blob, user_login, repo.name, Path.basename(commit_update_ref), blob_path))
                  end
                {:changes, new_name} ->
                  changeset = Ecto.Changeset.add_error(changeset, :name, "Cannot rename #{changeset.data.name} to #{new_name}")
                  conn = put_flash(conn, :error, "Something went wrong! Please check error(s) below.")
                  conn = put_status(conn, :bad_request)
                  render(conn, "edit.html",
                    repo: repo,
                    repo_open_issue_count: IssueQuery.count_repo_issues(repo, status: :open),
                    agent: agent,
                    revision: reference || commit,
                    commit: commit,
                    tree_path: blob_path,
                    breadcrumb: breadcrumb,
                    changeset: %{changeset|action: :update}
                  )
              end
            else
              conn = put_flash(conn, :error, "Something went wrong! Please check error(s) below.")
              conn = put_status(conn, :bad_request)
              render(conn, "edit.html",
                repo: repo,
                repo_open_issue_count: IssueQuery.count_repo_issues(repo, status: :open),
                agent: agent,
                revision: reference || commit,
                commit: commit,
                tree_path: blob_path,
                breadcrumb: breadcrumb,
                changeset: %{changeset|action: :update}
              )
            end
          end
        end || {:error, :forbidden}
      end
    end || {:error, :not_found}
  end

  @doc """
  Renders a blob delete form.
  """
  def confirm_delete(conn, %{"user_login" => user_login, "repo_name" => repo_name, "revision" => revision, "path" => blob_path} = _params) do
    unless Enum.empty?(blob_path) do
      user = current_user(conn)
      if repo = RepoQuery.user_repo(user_login, repo_name, viewer: user) do
        if authorized?(user, repo, :push) do
          with {:ok, agent} <- GitRepo.get_agent(repo),
               {:ok, {reference, commit, _blob_content, _blob_size}} <- GitAgent.transaction(agent, &resolve_blob(&1, revision, blob_path)) do
            render(conn, "confirm_delete.html",
              repo: repo,
              repo_open_issue_count: IssueQuery.count_repo_issues(repo, status: :open),
              agent: agent,
              revision: reference,
              commit: commit,
              tree_path: blob_path,
              breadcrumb: %{action: :tree, cwd?: true, tree?: false},
              changeset: commit_changeset(%{branch: reference.name}, %{})
            )
          end
        end || {:error, :forbidden}
      end
    end || {:error, :not_found}
  end


  @doc """
  Deletes an existing blob.
  """
  @spec delete(Plug.Conn.t, map) :: Plug.Conn.t
  def delete(conn, %{"user_login" => user_login, "repo_name" => repo_name, "revision" => revision, "path" => blob_path, "commit" => commit_params} = _params) do
    unless Enum.empty?(blob_path) do
      user = current_user(conn)
      if repo = RepoQuery.user_repo(user_login, repo_name, viewer: user) do
        if authorized?(user, repo, :push) do
          with {:ok, agent} <- GitRepo.get_agent(repo),
               {:ok, {reference, commit, _blob_content, _blob_size}} <- GitAgent.transaction(agent, &resolve_blob(&1, revision, blob_path)) do
            breadcrumb = %{action: :tree, cwd?: true, tree?: false}
            changeset = commit_changeset(%{}, commit_params)
            if changeset.valid? do # TODO
              tree_path = Enum.drop(blob_path, -1)
              commit_update_ref = commit_changeset_update_ref(changeset)
              commit_author_sig = commit_signature(user, DateTime.now!("Etc/UTC"))
              commit_committer_sig = commit_author_sig
              commit_message = commit_changeset_message(changeset)
              with {:ok, {reference_oid, commit_oid}} <- GitAgent.transaction(agent, &delete_blob(&1, commit, blob_path, commit_update_ref, commit_author_sig, commit_committer_sig, commit_message)),
                   {:ok, repo} <- GitRepo.push(repo, [{:update, reference_oid, commit_oid, commit_update_ref}]) do
                conn
                |> put_flash(:info, "File #{List.last(blob_path)} deleted.")
                |> redirect(to: Routes.codebase_path(conn, :tree, user_login, repo.name, Path.basename(commit_update_ref), tree_path))
              end
            else
              conn = put_flash(conn, :error, "Something went wrong! Please check error(s) below.")
              conn = put_status(conn, :bad_request)
              render(conn, "confirm_delete.html",
                repo: repo,
                repo_open_issue_count: IssueQuery.count_repo_issues(repo, status: :open),
                agent: agent,
                revision: reference || commit,
                commit: commit,
                tree_path: blob_path,
                breadcrumb: breadcrumb,
                changeset: %{changeset|action: :delete}
              )
            end
          end
        end || {:error, :forbidden}
      end
    end || {:error, :not_found}
  end

  @doc """
  Renders all branches of a repository.
  """
  @spec branches(Plug.Conn.t, map) :: Plug.Conn.t
  def branches(conn, %{"user_login" => user_login, "repo_name" => repo_name} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      with {:ok, agent} <- GitRepo.get_agent(repo),
           {:ok, {head, branches}} <- GitAgent.transaction(agent, &resolve_branches/1) do
        if head_index = Enum.find_index(branches, &match?({^head, _, _}, &1)) do
          head = Enum.at(branches, head_index)
          branches = Enum.sort_by(List.delete_at(branches, head_index), &elem(&1, 2), {:desc, Date})
          page = paginate(conn, branches)
          [{head, author, timestamp}|slice] = resolve_revisions_db([head|page.slice])
          case resolve_revisions_graph(agent, head, slice) do
            {:ok, slice} ->
              render(conn, "branch_list.html",
                repo: repo,
                repo_open_issue_count: IssueQuery.count_repo_issues(repo, status: :open),
                head: Map.merge(Map.take(head, [:oid, :name]), %{author: author, timestamp: timestamp}),
                page: Map.put(page, :slice, slice)
              )
            {:error, reason} ->
              {:error, reason}
          end
        else
          branches = Enum.sort_by(branches, &elem(&1, 2), {:desc, Date})
          page = paginate(conn, branches)
          slice = resolve_revisions_db(page.slice)
          slice = Enum.map(slice, fn {ref, author, timestamp} -> {ref, author, timestamp, {0, 0}} end)
          render(conn, "branch_list.html",
            repo: repo,
            repo_open_issue_count: IssueQuery.count_repo_issues(repo, status: :open),
            head: head,
            page: Map.put(page, :slice, slice)
          )
        end
      end
    end || {:error, :not_found}
  end

  @doc """
  Renders all tags of a repository.
  """
  @spec tags(Plug.Conn.t, map) :: Plug.Conn.t
  def tags(conn, %{"user_login" => user_login, "repo_name" => repo_name} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      case GitAgent.transaction(repo, &resolve_tags/1) do
        {:ok, tags} ->
          page = paginate(conn, Enum.sort_by(tags, &elem(&1, 2), {:desc, Date}))
          render(conn, "tag_list.html",
            repo: repo,
            repo_open_issue_count: IssueQuery.count_repo_issues(repo, status: :open),
            page: Map.update!(page, :slice, &resolve_revisions_db/1)
          )
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

  defp blob_commit_changeset(blob_commit, params) do
    Ecto.Changeset.merge(blob_changeset(blob_commit, params), commit_changeset(blob_commit, params))
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

  defp resolve_revisions(agent, revs) do
    GitAgent.transaction(agent, fn agent ->
      Enum.reduce_while(Enum.reverse(revs), {:ok, []}, &resolve_revision(agent, &1, &2))
    end)
  end

  defp resolve_revisions_graph(agent, head, revs) do
    GitAgent.transaction(agent, fn agent ->
      Enum.reduce_while(Enum.reverse(revs), {:ok, []}, &resolve_revision_graph(agent, head, &1, &2))
    end)
  end

  defp resolve_revisions_db(revs) do
    users = UserQuery.by_email(Enum.uniq(Enum.map(revs, &(elem(&1, 1).email))), preload: :emails)
    Enum.map(revs, fn {rev, author, timestamp} ->
      {rev, resolve_db_user(author, users), timestamp}
    end)
  end

  defp resolve_revision(agent, %GitRef{} = rev, {:ok, acc}) do
    with {:ok, commit} <- GitAgent.peel(agent, rev, target: :commit),
         {:ok, author} <- GitAgent.commit_author(agent, commit),
         {:ok, timestamp} <- GitAgent.commit_timestamp(agent, commit) do
      {:cont, {:ok, [{rev, author, timestamp}|acc]}}
    else
      {:error, reason} ->
        {:halt, {:error, reason}}
    end
  end

  defp resolve_revision(agent, %GitTag{} = tag, {:ok, acc}) do
    case GitAgent.tag_author(agent, tag) do
      {:ok, author} ->
        {:cont, {:ok, [{tag, author, author.timestamp}|acc]}}
      {:error, reason} ->
        {:halt, {:error, reason}}
    end
  end

  defp resolve_revision_graph(agent, head, {rev, author, timestamp}, {:ok, acc}) do
    case GitAgent.graph_ahead_behind(agent, rev.oid, head.oid) do
      {:ok, graph_diff} ->
        {:cont, {:ok, [{rev, author, timestamp, graph_diff}|acc]}}
      {:error, reason} ->
        {:halt, {:error, reason}}
    end
  end

  defp resolve_tree(agent, revision, []) do
    with {:ok, {object, reference}} <- GitAgent.revision(agent, revision),
         {:ok, commit} <- GitAgent.peel(agent, object, target: :commit),
         {:ok, tree} <- GitAgent.tree(agent, commit) do
      {:ok, {reference, commit, tree}}
    end
  end

  defp resolve_tree(agent, revision, tree_path) do
    with {:ok, {object, reference}} <- GitAgent.revision(agent, revision),
         {:ok, commit} <- GitAgent.peel(agent, object, target: :commit),
         {:ok, tree_entry} <- GitAgent.tree_entry_by_path(agent, commit, Path.join(tree_path)),
         {:ok, tree} <- GitAgent.peel(agent, tree_entry) do
      {:ok, {reference, commit, tree}}
    end
  end

  defp resolve_blob(agent, rev_spec, blob_path) do
    with {:ok, {object, reference}} <- GitAgent.revision(agent, rev_spec),
         {:ok, commit} <- GitAgent.peel(agent, object, target: :commit),
         {:ok, tree_entry} <- GitAgent.tree_entry_by_path(agent, commit, Path.join(blob_path)),
         {:ok, blob} <- GitAgent.peel(agent, tree_entry),
         {:ok, blob_content} <- GitAgent.blob_content(agent, blob),
         {:ok, blob_size} <- GitAgent.blob_size(agent, blob) do
      {:ok, {reference, commit, blob_content, blob_size}}
    end
  end

  defp resolve_branches(agent) do
    with {:ok, branches} <- GitAgent.branches(agent),
         {:ok, branches} <- resolve_revisions(agent, branches) do
      case GitAgent.head(agent) do
        {:ok, head} ->
          {:ok, {head, branches}}
        {:error, _reason} ->
          {:ok, {nil, branches}}
      end
    end
  end

  defp resolve_tags(agent) do
    case GitAgent.tags(agent) do
      {:ok, tags} ->
        resolve_revisions(agent, tags)
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp resolve_db_user(%{email: email} = map, users) do
    Enum.find(users, map, fn user -> email in Enum.map(user.emails, &(&1.address)) end)
  end

  defp write_blob(agent, commit, blob_path, blob_content, commit_update_ref, commit_author_sig, commit_committer_sig, commit_message) do
    with {:ok, tree} <- GitAgent.tree(agent, commit),
         {:ok, index} <- GitAgent.index(agent),
          :ok <- GitAgent.index_read_tree(agent, index, tree),
         {:ok, odb} <- GitAgent.odb(agent),
         {:ok, blob_oid} <- GitAgent.odb_write(agent, odb, blob_content, :blob),
          :ok <- GitAgent.index_add(agent, index, blob_oid, Path.join(blob_path), byte_size(blob_content), 0o100644),
         {:ok, tree_oid} <- GitAgent.index_write_tree(agent, index),
         {:ok, reference} <- GitAgent.reference(agent, commit_update_ref),
         {:ok, commit_oid} <- GitAgent.commit_create(agent, commit_author_sig, commit_committer_sig, commit_message, tree_oid, [commit.oid], update_ref: commit_update_ref) do
      {:ok, {reference.oid, commit_oid}}
    end
  end

  defp write_blob_new(agent, commit, tree, blob_path, blob_content, commit_update_ref, commit_author_sig, commit_committer_sig, commit_message) do
    case GitAgent.tree_entry_by_path(agent, tree, Path.join(blob_path)) do
      {:ok, tree_entry} ->
        {:error, {:already_exist, tree_entry}}
      {:error, _reason} ->
        with {:ok, index} <- GitAgent.index(agent),
              :ok <- GitAgent.index_read_tree(agent, index, tree),
             {:ok, odb} <- GitAgent.odb(agent),
             {:ok, blob_oid} <- GitAgent.odb_write(agent, odb, blob_content, :blob),
              :ok <- GitAgent.index_add(agent, index, blob_oid, Path.join(blob_path), byte_size(blob_content), 0o100644),
             {:ok, tree_oid} <- GitAgent.index_write_tree(agent, index),
             {:ok, reference} <- GitAgent.reference(agent, commit_update_ref),
             {:ok, commit_oid} <- GitAgent.commit_create(agent, commit_author_sig, commit_committer_sig, commit_message, tree_oid, [commit.oid], update_ref: commit_update_ref) do
          {:ok, {reference.oid, commit_oid}}
        end
    end
  end

  defp delete_blob(agent, commit, blob_path, commit_update_ref, commit_author_sig, commit_committer_sig, commit_message) do
    with {:ok, tree} <- GitAgent.tree(agent, commit),
         {:ok, index} <- GitAgent.index(agent),
          :ok <- GitAgent.index_read_tree(agent, index, tree),
          :ok <- GitAgent.index_remove(agent, index, Path.join(blob_path)),
         {:ok, tree_oid} <- GitAgent.index_write_tree(agent, index),
         {:ok, reference} <- GitAgent.reference(agent, commit_update_ref),
         {:ok, commit_oid} <- GitAgent.commit_create(agent, commit_author_sig, commit_committer_sig, commit_message, tree_oid, [commit.oid], update_ref: commit_update_ref) do
      {:ok, {reference.oid, commit_oid}}
    end
  end
end
