defmodule GitGud.Web.CodebaseView do
  @moduledoc false
  use GitGud.Web, :view

  alias GitRekt.GitAgent

  alias GitGud.User
  alias GitGud.UserQuery
  alias GitGud.Repo
  alias GitGud.ReviewQuery
  alias GitGud.Commit
  alias GitGud.CommitQuery
  alias GitGud.GPGKey
  alias GitGud.GPGKeyQuery

  alias Phoenix.Param

  alias GitRekt.{GitCommit, GitTag, GitTree, GitTreeEntry, GitBlob, GitDiff, GitRef}

  import Phoenix.Controller, only: [action_name: 1]

  import Phoenix.HTML.Tag

  import GitRekt.Git, only: [oid_fmt: 1, oid_fmt_short: 1]

  @external_resource highlight_languages = Path.join(:code.priv_dir(:gitgud_web), "highlight-languages.txt")

  @spec branch_select(Plug.Conn.t) :: binary
  def branch_select(conn) do
    %{repo: repo, revision: revision} = Map.take(conn.assigns, [:repo, :revision])
    revision_oid = revision_oid(revision)
    revision_name = revision_name(revision)
    revision_type = revision_type(revision)
    revision_href = revision_href(conn, revision)
    react_component("branch-select", [repo_id: to_relay_id(repo), oid: revision_oid, name: revision_name, type: revision_type, action_href: revision_action_href(conn), branch_href: revision_href(conn, :branches), tag_href: revision_href(conn, :tags)], [class: "branch-select"], do: [
      content_tag(:a, [class: "button", href: revision_href], do: [
        content_tag(:span, [], do: [
          "#{String.capitalize(to_string(revision_type))}: ",
          content_tag(:span, revision_name, class: "has-text-weight-semibold")
        ]),
        content_tag(:span, [class: "icon is-small"], do: [
          content_tag(:i, "", class: "fas fa-angle-down")
        ])
      ])
    ])
  end

  @spec clone_dropdown(Plug.Conn.t) :: binary
  def clone_dropdown(conn) do
    repo = Map.get(conn.assigns, :repo)
    props = %{http_url: Routes.codebase_url(conn, :show, repo.owner, repo)}
    props =
      if user = current_user(conn),
        do: Map.put(props, :ssh_url, "#{user.login}@#{GitGud.Web.Endpoint.struct_url().host}:#{repo.owner.login}/#{repo.name}"),
      else: props
    react_component("clone-dropdown", props, [class: "clone-dropdown"], do: [
      content_tag(:div, [class: "dropdown is-right is-hoverable"], do: [
        content_tag(:div, [class: "dropdown-trigger"], do: [
          content_tag(:button, [class: "button is-success"], do: [
            content_tag(:span, "Clone repository"),
            content_tag(:span, [class: "icon is-small"], do: [
              content_tag(:i, "", class: "fas fa-angle-down")
            ])
          ])
        ]),
        content_tag(:div, [class: "dropdown-menu"], do: [
          content_tag(:div, [class: "dropdown-content"], do: [
            content_tag(:div, [class: "dropdown-item"], do: [
              content_tag(:div, [class: "field"], do: [
                content_tag(:label, "Clone with HTTP", class: "label"),
                content_tag(:div, [class: "control is-expanded"], do: [
                  tag(:input, class: "input is-small", type: "text", readonly: true, value: props.http_url)
                ])
              ])
            ])
          ])
        ])
      ])
    ])
  end

  @spec breadcrumb_action(atom) :: atom
  def breadcrumb_action(:blob), do: :tree
  def breadcrumb_action(action), do: action

  @spec breadcrumb_tree?(Plug.Conn.t) :: boolean
  def breadcrumb_tree?(conn) do
    action = Phoenix.Controller.action_name(conn)
    cond do
      action == :tree -> true
      action == :blob -> false
      true ->
        %{repo: repo, revision: revision, tree_path: tree_path} = conn.assigns
        with {:ok, tree} <- GitAgent.tree(repo, revision),
             {:ok, tree_entry} <- GitAgent.tree_entry_by_path(repo, tree, Path.join(tree_path)) do
          tree_entry.type == :tree
        else
          {:error, reason} -> raise reason
        end
   end
  end

  @spec repo_head(Repo.t) :: GitRef.t | nil
  def repo_head(repo) do
    case GitAgent.head(repo) do
      {:ok, branch} -> branch
      {:error, _reason} -> nil
    end
  end
  @spec blob_content(Repo.t, GitBlob.t) :: binary | nil
  def blob_content(repo, blob) do
    case GitAgent.blob_content(repo, blob) do
      {:ok, content} -> content
      {:error, _reason} -> nil
    end
  end

  @spec blob_size(Repo.t, GitBlob.t) :: non_neg_integer | nil
  def blob_size(repo, blob) do
    case GitAgent.blob_size(repo, blob) do
      {:ok, size} -> size
      {:error, _reason} -> nil
    end
  end

  @spec commit_author(Repo.t, Commit.t | GitCommit.t) :: User.t | map | nil
  def commit_author(repo, commit) do
    if author = fetch_author(repo, commit) do
      if user = UserQuery.by_email(author.email),
        do: user,
      else: author
    end
  end

  @spec commit_author(Repo.t, Commit.t | GitCommit.t, :with_committer) :: {User.t | map | nil, User.t | map | nil}
  def commit_author(repo, commit, :with_committer) do
    author = fetch_author(repo, commit)
    author_user = UserQuery.by_email(author.email, preload: [:emails]) || author
    committer = fetch_committer(repo, commit)
    if author.email == committer.email,
     do: {author_user, author_user},
   else: {author_user, UserQuery.by_email(committer.email) || committer}
  end

  @spec commit_committer(Repo.t, Commit.t | GitCommit.t) :: User.t | map | nil
  def commit_committer(repo, commit) do
    if committer = fetch_committer(repo, commit) do
      if user = UserQuery.by_email(committer.email),
        do: user,
      else: committer
    end
  end

  @spec commit_timestamp(Repo.t, Commit.t | GitCommit.t) :: DateTime.t | nil
  def commit_timestamp(_repo, %Commit{} = commit), do: commit.committed_at
  def commit_timestamp(repo, commit) do
    case GitAgent.commit_timestamp(repo, commit) do
      {:ok, timestamp} -> timestamp
      {:error, _reason} -> nil
    end
  end

  @spec commit_message(Repo.t, Commit.t | GitCommit.t) :: binary | nil
  def commit_message(_repo, %Commit{} = commit), do: commit.message
  def commit_message(repo, commit) do
    case GitAgent.commit_message(repo, commit) do
      {:ok, message} -> message
      {:error, _reason} -> nil
    end
  end

  @spec commit_message_title(Repo.t, Commit.t | GitCommit.t) :: binary | nil
  def commit_message_title(repo, commit) do
    if message = commit_message(repo, commit) do
      List.first(String.split(message, "\n", trim: true, parts: 2))
    end
  end

  @spec commit_message_body(Repo.t, Commit.t | GitCommit.t) :: binary | nil
  def commit_message_body(repo, commit) do
    if message = commit_message(repo, commit) do
      List.last(String.split(message, "\n", trim: true, parts: 2))
    end
  end

  @spec commit_message_format(Repo.t, Commit.t | GitCommit.t, keyword) :: {binary, binary | nil} | nil
  def commit_message_format(repo, commit, opts \\ []) do
    if message = commit_message(repo, commit) do
      parts = String.split(message, "\n", trim: true, parts: 2)
      if length(parts) == 2,
        do: {List.first(parts), wrap_message(List.last(parts), Keyword.get(opts, :wrap, :pre))},
      else: {List.first(parts), nil}
    end
  end

  @spec commit_review(Repo.t, Commit.t | GitCommit.t) :: CommitReview.t | nil
  def commit_review(repo, commit) do
    ReviewQuery.commit_review(repo, commit)
  end

  @spec commit_gpg_key(Repo.t, Commit.t | GitCommit.t) :: GPGKey.t | nil
  def commit_gpg_key(repo, %Commit{} = commit) do
    CommitQuery.gpg_signature(repo, commit)
  end

  def commit_gpg_key(repo, %GitCommit{} = commit) do
    case GitAgent.commit_gpg_signature(repo, commit) do
      {:ok, gpg_sig} ->
        gpg_sig
        |> GPGKey.decode!()
        |> GPGKey.parse!()
        |> get_in([:sig, :sub_pack, :issuer])
        |> GPGKeyQuery.by_key_id()
      {:error, _reason} -> nil
    end
  end

  @spec revision_oid(GitAgent.git_object) :: binary
  def revision_oid(%{oid: oid} = _object), do: oid_fmt(oid)

  @spec revision_name(GitAgent.git_object) :: binary
  def revision_name(%GitCommit{oid: oid} = _object = _object), do: oid_fmt_short(oid)
  def revision_name(%GitRef{name: name} = _object), do: name
  def revision_name(%GitTag{name: name} = _object), do: name

  @spec revision_type(GitAgent.git_object) :: atom
  def revision_type(%GitCommit{} = _object), do: :commit
  def revision_type(%GitTag{} = _object), do: :tag
  def revision_type(%GitRef{type: type} = _object), do: type

  @spec revision_href(Plug.Conn.t, GitAgent.git_object | atom) :: binary
  def revision_href(conn, revision_type) when is_atom(revision_type) do
    Routes.codebase_path(conn, revision_type, conn.path_params["user_login"], conn.path_params["repo_name"])
  end

  def revision_href(conn, revision) do
    repo = conn.assigns.repo
    case revision_type(revision) do
      :branch ->
        Routes.codebase_path(conn, :branches, repo.owner, repo)
      :tag ->
        Routes.codebase_path(conn, :tags, repo.owner, repo)
      :commit ->
        Routes.codebase_path(conn, :history, repo.owner, repo, revision, [])
    end
  end

  @spec revision_action_href(Plug.Conn.t) :: binary
  def revision_action_href(conn) do
    %{repo: repo, tree_path: tree_path} = Map.take(conn.assigns, [:repo, :tree_path])
    case action_name(conn) do
      :show -> Routes.codebase_path(conn, :tree, repo.owner, repo, "__rev__", tree_path)
      :tree -> Routes.codebase_path(conn, :tree, repo.owner, repo, "__rev__", tree_path)
      :blob -> Routes.codebase_path(conn, :blob, repo.owner, repo, "__rev__", tree_path)
      :history -> Routes.codebase_path(conn, :history, repo.owner, repo, "__rev__", tree_path)
    end
  end

  @spec tree_entries(Repo.t, GitTree.t) :: [GitTreeEntry.t]
  def tree_entries(repo, tree) do
    case GitAgent.tree_entries(repo, tree) do
      {:ok, entries} -> entries
      {:error, _reason} -> []
    end
  end

  @spec tree_readme(Repo.t, GitTree.t) :: binary | nil
  def tree_readme(repo, tree) do
    with {:ok, entry} <- GitAgent.tree_entry_by_path(repo, tree, "README.md"),
         {:ok, blob} <- GitAgent.tree_entry_target(repo, entry),
         {:ok, content} <- GitAgent.blob_content(repo, blob) do
      markdown_safe(content)
    else
      {:error, _reason} -> nil
    end
  end

  @spec diff_stats(Repo.t, GitDiff.t) :: map | nil
  def diff_stats(repo, diff) do
    case GitAgent.diff_stats(repo, diff) do
      {:ok, stats} -> stats
      {:error, _reason} -> nil
    end
  end

  @spec diff_deltas(Repo.t, GitDiff.t) :: [map] | nil
  def diff_deltas(repo, diff) do
    case GitAgent.diff_deltas(repo, diff) do
      {:ok, deltas} -> deltas
      {:error, _reason} -> []
    end
  end

  @spec diff_deltas_with_reviews(Repo.t, GitCommit.t, GitDiff.t) :: [map] | nil
  def diff_deltas_with_reviews(repo, commit, diff) do
    commit_reviews = ReviewQuery.commit_line_reviews(repo, commit)
    Enum.map(diff_deltas(repo, diff), fn delta ->
      reviews = Enum.filter(commit_reviews, &(&1.blob_oid in [delta.old_file.oid, delta.new_file.oid]))
      Enum.reduce(reviews, delta, fn review, delta ->
        update_in(delta.hunks, fn hunks ->
          List.update_at(hunks, review.hunk, &attach_review_to_delta_line(&1, review.line, review))
        end)
      end)
    end)
  end

  @spec diff_deltas_with_comments(Repo.t, GitCommit.t, GitDiff.t) :: [map] | nil
  def diff_deltas_with_comments(repo, commit, diff) do
    commit_reviews = ReviewQuery.commit_line_reviews(repo, commit, preload: [comments: :author])
    Enum.map(diff_deltas(repo, diff), fn delta ->
      reviews = Enum.filter(commit_reviews, &(&1.blob_oid in [delta.old_file.oid, delta.new_file.oid]))
      Enum.reduce(reviews, delta, fn review, delta ->
        update_in(delta.hunks, fn hunks ->
          List.update_at(hunks, review.hunk, &attach_review_comments_to_delta_line(&1, review.line, review.comments))
        end)
      end)
    end)
  end

  @spec highlight_language_from_path(binary) :: binary
  def highlight_language_from_path(path) do
    highlight_language(Path.extname(path))
  end

  @spec batch_commits(Repo.t, Enumerable.t) :: [{GitCommit.t, User.t | map, boolean, non_neg_integer}]
  def batch_commits(repo, commits) do
    batch_commits_comments_count(repo, commits)
  end

  @spec batch_branches(Repo.t, Enumerable.t) :: [{GitRef.t, {GitCommit.t, User.t | map}}]
  def batch_branches(repo, references_commits) do
    {references, commits} = Enum.unzip(references_commits)
    commits_authors = batch_commits_authors(repo, commits)
    Enum.zip(references, commits_authors)
  end

  @spec batch_tags(Repo.t, Enumerable.t) :: [{GitRef.t | GitTag.t, {GitCommit.t, User.t | map}}]
  def batch_tags(repo, tags_commits) do
    {tags, commits} = Enum.unzip(tags_commits)
    authors = Enum.map(tags_commits, &fetch_author(repo, &1))
    users = query_users(authors)
    Enum.zip(tags, Enum.map(Enum.zip(commits, authors), &zip_author(&1, users)))
  end

  @spec sort_revisions_by_timestamp(Repo.t, Enumerable.t) :: [{GitRef.t | GitTag.t, GitCommit.t}]
  def sort_revisions_by_timestamp(repo, revisions) do
    commits = Enum.map(revisions, &fetch_commit(repo, &1))
    Enum.sort_by(Enum.zip(revisions, commits), &commit_timestamp(repo, elem(&1, 1)), &compare_timestamps/2)
  end

  @spec sort_tree_entries_by_name(Enumerable.t) :: [{GitTreeEntry.t, GitCommit.t}]
  def sort_tree_entries_by_name(tree_entries_commits) do
    Enum.sort_by(tree_entries_commits, fn {tree_entry, _commit} -> tree_entry.name end)
  end

  @spec chunk_by_timestamp(Repo.t, Enumerable.t) :: Enumerable.t
  def chunk_by_timestamp(repo, commits) do
    repo
    |> chunk_batched_commits_by_timestamp(commits)
    |> order_commits_chunks()
  end

  @spec title(atom, map) :: binary
  def title(:show, %{repo: repo}) do
    if desc = repo.description,
      do: "#{repo.owner.login}/#{repo.name}: #{desc}",
    else: "#{repo.owner.login}/#{repo.name}"
  end

  def title(:branches, %{repo: repo}), do: "Branches · #{repo.owner.login}/#{repo.name}"
  def title(:tags, %{repo: repo}), do: "Tags · #{repo.owner.login}/#{repo.name}"
  def title(:commit, %{repo: repo, commit: commit}), do: "#{commit_message_title(repo, commit)} · #{repo.owner.login}/#{repo.name}@#{oid_fmt_short(commit.oid)}"
  def title(:tree, %{repo: repo, revision: rev, tree_path: []}), do: "#{Param.to_param(rev)} · #{repo.owner.login}/#{repo.name}"
  def title(:tree, %{repo: repo, revision: rev, tree_path: path}), do: "#{Path.join(path)} at #{Param.to_param(rev)} · #{repo.owner.login}/#{repo.name}"
  def title(:blob, %{repo: repo, revision: rev, tree_path: path}), do: "#{Path.join(path)} at #{Param.to_param(rev)} · #{repo.owner.login}/#{repo.name}"
  def title(:history, %{repo: repo, revision: rev, tree_path: []}), do: "Commits at #{Param.to_param(rev)} · #{repo.owner.login}/#{repo.name}"
  def title(:history, %{repo: repo, revision: rev, tree_path: path}), do: "Commits at #{Param.to_param(rev)} · #{repo.owner.login}/#{repo.name}/#{Path.join(path)}"

  #
  # Helpers
  #

  defp batch_commits_authors(repo, commits) do
    authors = Enum.map(commits, &fetch_author(repo, &1))
    users = query_users(authors)
    Enum.map(Enum.zip(commits, authors), &zip_author(&1, users))
  end

  defp batch_commits_committers(repo, commits) do
    authors = Enum.map(commits, &fetch_author(repo, &1))
    authors_emails = Enum.map(authors, &(&1.email))
    all_committers = Map.new(commits, &{&1.oid, fetch_committer(repo, &1)})
    committers = Enum.filter(all_committers, fn {_oid, committer} -> committer.email in authors_emails end)
    committers = Enum.into(committers, %{})
    users = query_users(authors ++ Map.values(committers))
    commits
    |> Enum.zip(authors)
    |> Enum.map(fn {commit, author} -> {commit, author, Map.get(committers, commit.oid, all_committers[commit.oid] || author)} end)
    |> Enum.map(&zip_author(&1, users))
  end

  defp batch_commits_gpg_sign(repo, commits) do
    batch = batch_commits_committers(repo, commits)
    commits = Enum.filter(batch, fn
      {_commit, _author, %User{}} -> true
      {_commit, _author, _committer} -> false
    end)
    gpg_map =
      cond do
        Enum.all?(commits, fn
          {%Commit{}, _author, _committer} -> true
          {%GitCommit{}, _author, _committer} -> false
        end) ->
          CommitQuery.gpg_signature(repo, Enum.map(commits, &elem(&1, 0)))
        Enum.all?(commits, fn
          {%GitCommit{}, _author, _committer} -> true
          {%Commit{}, _author, _committer} -> false
        end) ->
          commits_gpg_key_ids =
            Map.new(commits, fn {commit, _author, _committer} ->
              case GitAgent.commit_gpg_signature(repo, commit) do
                {:ok, gpg_sig} ->
                  gpg_key_id =
                    gpg_sig
                    |> GPGKey.decode!()
                    |> GPGKey.parse!()
                    |> get_in([:sig, :sub_pack, :issuer])
                  {commit.oid, gpg_key_id}
                {:error, _reason} ->
                  nil
              end
            end)
          gpg_keys =
            commits_gpg_key_ids
            |> Map.values()
            |> Enum.uniq()
            |> GPGKeyQuery.by_key_id()
          Map.new(commits_gpg_key_ids, fn {oid, gpg_key_id} ->
            {oid, Enum.find(gpg_keys, &(binary_part(&1.key_id, 20, -8) == gpg_key_id))}
          end)
      end
    Enum.map(batch, fn
      {commit, author, %User{} = committer} ->
        {commit, author, committer, gpg_map[commit.oid]}
      {commit, author, committer} ->
        {commit, author, committer, nil}
    end)
  end

  defp batch_commits_comments_count(repo, commits) do
    aggregator = Map.new(ReviewQuery.commit_comment_count(repo, commits))
    Enum.map(batch_commits_gpg_sign(repo, commits), fn {commit, author, committer, gpg_key} -> {commit, author, committer, gpg_key, aggregator[commit.oid] || 0} end)
  end

  defp fetch_commit(repo, obj) do
    case GitAgent.peel(repo, obj, :commit) do
      {:ok, commit} -> commit
      {:error, _reason} -> nil
    end
  end

  defp fetch_author(repo, %GitRef{} = reference) do
    case GitAgent.peel(repo, reference) do
      {:ok, object} ->
        fetch_author(repo, object)
      {:error, _reason} -> nil
    end
  end

  defp fetch_author(repo, %GitCommit{} = commit) do
    case GitAgent.commit_author(repo, commit) do
      {:ok, sig} -> sig
      {:error, _reason} -> nil
    end
  end

  defp fetch_author(repo, %GitTag{} = tag) do
    case GitAgent.tag_author(repo, tag) do
      {:ok, sig} -> sig
      {:error, _reason} -> nil
    end
  end

  defp fetch_author(repo, {%GitRef{} = _reference, commit}) do
    fetch_author(repo, commit)
  end

  defp fetch_author(repo, {%GitTag{} = tag, _commit}) do
    fetch_author(repo, tag)
  end

  defp fetch_author(_repo, %Commit{} = commit) do
    %{name: commit.author_name, email: commit.author_email, timestamp: commit.committed_at}
  end

  defp fetch_committer(repo, %GitRef{} = reference) do
    case GitAgent.peel(repo, reference, :commit) do
      {:ok, commit} ->
        fetch_committer(repo, commit)
      {:error, _reason} -> nil
    end
  end

  defp fetch_committer(repo, %GitTag{} = tag) do
    case GitAgent.peel(repo, tag, :commit) do
      {:ok, commit} ->
        fetch_committer(repo, commit)
      {:error, _reason} -> nil
    end
  end

  defp fetch_committer(repo, %GitCommit{} = commit) do
    case GitAgent.commit_committer(repo, commit) do
      {:ok, sig} -> sig
      {:error, _reason} -> nil
    end
  end

  defp fetch_committer(repo, {%GitRef{} = _reference, commit}) do
    fetch_committer(repo, commit)
  end

  defp fetch_committer(_repo, %Commit{} = commit) do
    %{name: commit.author_name, email: commit.author_email, timestamp: commit.committed_at}
  end

  defp fetch_timestamp(repo, %GitCommit{} = commit) do
    case GitAgent.commit_timestamp(repo, commit) do
      {:ok, timestamp} -> timestamp
      {:error, _reason} -> nil
    end
  end

  defp fetch_timestamp(_repo, %Commit{} = commit) do
    DateTime.from_naive!(commit.committed_at, "Etc/UTC")
  end

  defp find_commit_timestamp({timestamp, _}, timestamp), do: true
  defp find_commit_timestamp({_, _}, _), do: false

  defp chunk_batched_commits_by_timestamp(repo, commits) do
    Enum.reduce(commits, [], fn {commit, _author, _committer, _gpg_key, _comment_count} = tuple, acc ->
      timestamp = DateTime.to_date(fetch_timestamp(repo, commit))
      idx = Enum.find_index(acc, &find_commit_timestamp(&1, timestamp))
      if idx,
        do: List.update_at(acc, idx, fn {timestamp, tuples} -> {timestamp, [tuple|tuples]} end),
      else: [{timestamp, [tuple]}|acc]
    end)
  end

  defp order_commits_chunks(chunks) do
    chunks
    |> Enum.reverse()
    |> Enum.map(fn {timestamp, commits} -> {timestamp, Enum.reverse(commits)} end)
  end

  defp query_users(authors) do
    authors
    |> Enum.map(&(&1.email))
    |> Enum.uniq()
    |> UserQuery.by_email(preload: :emails)
    |> Enum.flat_map(&flatten_user_emails/1)
    |> Map.new()
  end

  defp flatten_user_emails(user) do
    Enum.map(user.emails, &{&1.address, user})
  end

  for line <- File.stream!(highlight_languages) do

    [language|extensions] = String.split(String.trim(line), ~r/\s/, trim: true)
    for extension <- extensions do
      defp highlight_language("." <> unquote(extension)), do: unquote(language)
    end
  end

  defp highlight_language(_extension), do: "plaintext"

  defp wrap_message(content, :pre) do
    content = String.trim(content)
    if content != "", do: content_tag(:pre, String.trim(content))
  end

  defp wrap_message(content, :br) do
    content = String.trim(content)
    if content != "" do
      content
      |> String.split("\n\n", trim: true)
      |> Enum.map(&content_tag(:p, wrap_paragraph(&1)))
    end
  end

  defp wrap_message(content, max_line_length) do
    content = String.trim(content)
    if content != "" do
      content
      |> String.split("\n\n", trim: true)
      |> Enum.map(&content_tag(:p, wrap_paragraph(&1, max_line_length)))
    end
  end

  defp wrap_paragraph(content) do
    content = String.trim(content)
    if content != "" do
      content
      |> String.split("\n", trim: true)
      |> Enum.intersperse(tag(:br))
    end
  end

  defp wrap_paragraph(content, max_line_length) do
    content = String.trim(content)
    if content != "" do
      [word|rest] = String.split(content, ~r/\s+/, trim: true)
      Enum.intersperse(lines_assemble(rest, max_line_length, String.length(word), word, []), tag(:br))
    end
  end

  defp lines_assemble([], _, _, line, acc), do: Enum.reverse([line|acc])
  defp lines_assemble([word|rest], max, line_length, line, acc) do
    if line_length + 1 + String.length(word) > max,
      do: lines_assemble(rest, max, String.length(word), word, [line|acc]),
    else: lines_assemble(rest, max, line_length + 1 + String.length(word), line <> " " <> word, acc)
  end

  defp compare_timestamps(one, two) do
    case DateTime.compare(one, two) do
      :gt -> true
      :eq -> false
      :lt -> false
    end
  end

  defp attach_review_to_delta_line(hunk, line, review) do
    update_in(hunk.lines, fn lines ->
      List.update_at(lines, line, &Map.put(&1, :review, review))
    end)
  end


  defp attach_review_comments_to_delta_line(hunk, line, comments) do
    update_in(hunk.lines, fn lines ->
      List.update_at(lines, line, &Map.put(&1, :comments, comments))
    end)
  end

  defp zip_author({commit, author}, users) do
    {commit, Map.get(users, author.email, author)}
  end

  defp zip_author({commit, author, author}, users) do
    user = Map.get(users, author.email, author)
    {commit, user, user}
  end

  defp zip_author({commit, author, committer}, users) do
    {commit, Map.get(users, author.email, author), Map.get(users, committer.email, committer)}
  end
end
