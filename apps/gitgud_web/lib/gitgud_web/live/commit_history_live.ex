defmodule GitGud.Web.CommitHistoryLive do
  @moduledoc """
  Live view responsible for rendering Git commit ancestors.
  """

  use GitGud.Web, :live_view

  alias GitRekt.GitRepo
  alias GitRekt.GitAgent

  alias GitGud.DB
  alias GitGud.DBQueryable

  alias GitGud.User
  alias GitGud.ReviewQuery
  alias GitGud.GPGKey

  alias GitGud.UserQuery
  alias GitGud.RepoQuery

  import GitRekt.Git, only: [oid_fmt: 1, oid_parse: 1]

  import GitGud.Web.CodebaseView

  #
  # Callbacks
  #

  @impl true
  def mount(%{"user_login" => user_login, "repo_name" => repo_name} = _params, session, socket) do
    {
      :ok,
      socket
      |> authenticate(session)
      |> assign(rev_spec: nil, revision: nil, commit: nil)
      |> assign_repo!(user_login, repo_name)
      |> assign_repo_open_issue_count()
      |> assign_agent!()
    }
  end

  @impl true
  def handle_params(_params, _uri, socket) when is_nil(socket.assigns.repo.pushed_at) do
    {:noreply, assign_page_title(socket)}
  end

  def handle_params(params, _uri, socket) when is_map_key(params, "revision") do
    {
      :noreply,
      socket
      |> assign_history!(params)
      |> assign_page_title()
    }
  end

  def handle_params(params, _uri, socket) do
    case GitAgent.head(socket.assigns.agent) do
      {:ok, head} ->
        {:noreply, push_patch(socket, to: Routes.codebase_path(socket, :history, socket.assigns.repo.owner_login, socket.assigns.repo.name, head, Map.get(params, "path", [])))}
      {:error, error} ->
        {:noreply, put_flash(socket, :error, error)}
    end
  end

  #
  # Helpers
  #

  defp assign_repo!(socket, user_login, repo_name) do
    query = DBQueryable.query({RepoQuery, :user_repo_query}, [user_login, repo_name], viewer: current_user(socket))
    assign(socket, :repo, DB.one!(query))
  end

  defp assign_repo_open_issue_count(socket) do
    assign(socket, :repo_open_issue_count, GitGud.IssueQuery.count_repo_issues(socket.assigns.repo, status: :open))
  end

  defp assign_agent!(socket) do
    case GitRepo.get_agent(socket.assigns.repo) do
      {:ok, agent} ->
        assign(socket, :agent, agent)
      {:error, error} ->
        raise error
    end
  end

  defp assign_history!(socket, params) do
    rev_spec = params["revision"]
    tree_path = params["path"] || []
    resolve_revision? = is_nil(socket.assigns.commit) or rev_spec != socket.assigns.rev_spec
    cursor = pagination_cursor(params)
    limit = 20
    socket
    |> assign(:tree_path, tree_path)
    |> assign(resolve_revision_history!(socket.assigns.repo, socket.assigns.agent, resolve_revision? && rev_spec || socket.assigns.commit, tree_path, cursor, limit))
  end

  defp assign_page_title(socket) do
    assign(socket, :page_title, GitGud.Web.CodebaseView.title(socket.assigns[:live_action], socket.assigns))
  end

  defp resolve_revision_history!(repo, agent, revision, tree_path, cursor, limit) do
    case GitAgent.transaction(agent, &resolve_revision_history(&1, revision, tree_path, cursor, limit)) do
      {:ok, {head, ref, commit, tree_entry_type, {slice, more?}}} ->
        page = pagination_page(resolve_commits_info_db(repo, slice), cursor, more?)
        %{head: head, revision: ref || commit, commit: commit, tree_entry_type: tree_entry_type, page: page}
      {:ok, {tree_entry_type, {slice, more?}}} ->
        page = pagination_page(resolve_commits_info_db(repo, slice), cursor, more?)
        %{tree_entry_type: tree_entry_type, page: page}
      {:error, error} ->
        raise error
    end
  end

  defp resolve_revision_history(agent, commit, tree_path, cursor, limit) when is_struct(commit), do: resolve_history(agent, commit, tree_path, cursor, limit)
  defp resolve_revision_history(agent, rev_spec, tree_path, cursor, limit) do
    with {:ok, {obj, ref}} <- GitAgent.revision(agent, rev_spec),
         {:ok, commit} <- GitAgent.peel(agent, obj, target: :commit),
         {:ok, {tree_entry_type, page}} <- resolve_history(agent, commit, tree_path, cursor, limit) do
      case GitAgent.head(agent) do
        {:ok, head} ->
          {:ok, {head, ref, commit, tree_entry_type, page}}
        {:error, _reason} ->
          {:ok,{nil, ref, commit, tree_entry_type, page}}
      end
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp resolve_history(agent, commit, tree_path, cursor, limit) do
    opts = Enum.empty?(tree_path) && [] || [pathspec: Path.join(tree_path)]
    with {:ok, tree_entry_type} <- resolve_tree_entry_type(agent, commit, tree_path),
         {:ok, history} <- GitAgent.history(agent, commit, opts),
         {:ok, {slice, more?}} <- paginate_history(history, cursor, limit),
         {:ok, slice} <- resolve_commits_infos(agent, slice) do
      {:ok, {tree_entry_type, {slice, more?}}}
    end
  end

  defp resolve_tree_entry_type(_agent, _commit, []), do: {:ok, :tree}
  defp resolve_tree_entry_type(agent, commit, tree_path) do
    case GitAgent.tree_entry_by_path(agent, commit, Path.join(tree_path)) do
      {:ok, tree_entry} ->
        {:ok, tree_entry.type}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp resolve_commits_infos(agent, commits) do
    Enum.reduce_while(Enum.reverse(commits), {:ok, []}, &resolve_commit_info(agent, &1, &2))
  end

  defp resolve_commits_info_db(repo, commits_infos) do
    {commits, infos} = Enum.unzip(commits_infos)
    users = UserQuery.by_email(Enum.uniq(Enum.flat_map(infos, &[&1.author.email, &1.committer.email])), preload: [:emails, :gpg_keys])
    count = Map.new(ReviewQuery.count_comments(repo, commits))
    Enum.map(commits_infos, fn {commit, commit_info} ->
      author = resolve_db_user(commit_info.author, users)
      committer = resolve_db_user(commit_info.committer, users)
      gpg_key = resolve_db_user_gpg_key(commit_info.gpg_sig, committer)
      {commit, Map.merge(commit_info, %{author: author, committer: committer, gpg_key: gpg_key}), Map.get(count, commit.oid, 0)}
    end)
  end

  defp resolve_commit_info(agent, commit, {:ok, acc}) do
    case resolve_commit_info(agent, commit) do
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

  defp paginate_history(stream, {:before, cursor_oid}, limit) do
    stream = Enum.reverse(Stream.take_while(stream, &(&1.oid != cursor_oid)))
    stream = Stream.take(stream, limit+1)
    slice = Enum.to_list(stream)
    {:ok, {Enum.reverse(Enum.take(slice, limit)), Enum.count(slice) > limit}}
  end

  defp paginate_history(stream, {:after, cursor_oid}, limit) do
    stream = Stream.drop(Stream.drop_while(stream, &(&1.oid != cursor_oid)), 1)
    stream = Stream.take(stream, limit+1)
    slice = Enum.to_list(stream)
    {:ok, {Enum.take(slice, limit), Enum.count(slice) > limit}}
  end

  defp paginate_history(stream, nil, limit) do
    stream = Stream.take(stream, limit+1)
    slice = Enum.to_list(stream)
    {:ok, {Enum.take(slice, limit), Enum.count(slice) > limit}}
  end

  defp paginate_history(_stream, _cursor, _limit) do
    {:error, :invalid_cursor}
  end

  defp pagination_page(slice, {:before, _cursor_oid}, more?) do
    %{
      slice: slice,
      previous?: more?,
      before: more? && oid_fmt(elem(List.first(slice), 0).oid) || nil,
      next?: true,
      after: !Enum.empty?(slice) && oid_fmt(elem(List.last(slice), 0).oid) || nil
    }
  end

  defp pagination_page(slice, {:after, _cursor_oid}, more?) do
    %{
      slice: slice,
      previous?: true,
      before: !Enum.empty?(slice) && oid_fmt(elem(List.first(slice), 0).oid) || nil,
      next?: more?,
      after: more? && oid_fmt(elem(List.last(slice), 0).oid) || nil
    }
  end

  defp pagination_page(slice, nil, more?) do
    %{
      slice: slice,
      previous?: false,
      before: nil,
      next?: more?,
      after: more? && oid_fmt(elem(List.last(slice), 0).oid) || nil
    }
  end

  defp pagination_cursor(%{"before" => cursor}), do: {:before, oid_parse(cursor)}
  defp pagination_cursor(%{"after" => cursor}), do: {:after, oid_parse(cursor)}
  defp pagination_cursor(_params), do: nil
end
