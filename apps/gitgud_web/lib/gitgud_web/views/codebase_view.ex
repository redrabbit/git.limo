defmodule GitGud.Web.CodebaseView do
  @moduledoc false
  use GitGud.Web, :view

  alias GitRekt.GitAgent

  alias GitGud.User
  alias GitGud.UserQuery
  alias GitGud.Repo
  alias GitGud.ReviewQuery
  alias GitGud.GPGKey
  alias GitGud.GPGKeyQuery
  alias GitGud.Issue
  alias GitGud.IssueQuery

  alias Phoenix.Param

  alias GitRekt.{GitCommit, GitTag, GitTree, GitTreeEntry, GitBlob, GitDiff, GitRef}

  import Phoenix.Controller, only: [action_name: 1]

  import Phoenix.HTML.Link
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

  @spec blob_content(GitAgent.agent, GitBlob.t) :: binary | nil
  def blob_content(agent, blob) do
    case GitAgent.blob_content(agent, blob) do
      {:ok, content} -> content
      {:error, _reason} -> nil
    end
  end

  @spec blob_size(GitAgent.agent, GitBlob.t) :: non_neg_integer | nil
  def blob_size(agent, blob) do
    case GitAgent.blob_size(agent, blob) do
      {:ok, size} -> size
      {:error, _reason} -> nil
    end
  end

  @spec commit_author(GitAgent.agent, GitCommit.t) :: User.t | map | nil
  def commit_author(agent, commit) do
    if author = fetch_author(agent, commit) do
      if user = UserQuery.by_email(author.email),
        do: user,
      else: author
    end
  end

  @spec commit_author(GitAgent.agent, GitCommit.t, :with_committer) :: {User.t | map | nil, User.t | map | nil}
  def commit_author(agent, commit, :with_committer) do
    author = fetch_author(agent, commit)
    author_user = UserQuery.by_email(author.email, preload: [:emails]) || author
    committer = fetch_committer(agent, commit)
    if author.email == committer.email,
     do: {author_user, author_user},
   else: {author_user, UserQuery.by_email(committer.email) || committer}
  end

  @spec commit_committer(GitAgent.agent, GitCommit.t) :: User.t | map | nil
  def commit_committer(agent, commit) do
    if committer = fetch_committer(agent, commit) do
      if user = UserQuery.by_email(committer.email),
        do: user,
      else: committer
    end
  end

  @spec commit_timestamp(GitAgent.agent, GitCommit.t) :: DateTime.t | nil
  def commit_timestamp(agent, commit) do
    case GitAgent.commit_timestamp(agent, commit) do
      {:ok, timestamp} -> timestamp
      {:error, _reason} -> nil
    end
  end

  @spec commit_message(GitAgent.agent, GitCommit.t) :: binary | nil
  def commit_message(agent, commit) do
    case GitAgent.commit_message(agent, commit) do
      {:ok, message} -> message
      {:error, _reason} -> nil
    end
  end

  @spec commit_message_title(GitAgent.agent, GitCommit.t) :: binary | nil
  def commit_message_title(agent, commit) do
    if message = commit_message(agent, commit) do
      List.first(String.split(message, "\n", trim: true, parts: 2))
    end
  end

  @spec commit_message_body(GitAgent.agent, GitCommit.t) :: binary | nil
  def commit_message_body(agent, commit) do
    if message = commit_message(agent, commit) do
      List.last(String.split(message, "\n", trim: true, parts: 2))
    end
  end

  @spec commit_message_format(Repo.t, GitAgent.agent, GitCommit.t, keyword) :: {binary, binary | nil} | nil
  def commit_message_format(repo, agent, commit, opts \\ []) do
    if message = commit_message(agent, commit) do
      issues = find_issue_references(message, repo)
      parts = String.split(message, "\n", trim: true, parts: 2)
      if length(parts) == 2,
        do: {replace_issue_references(List.first(parts), repo, issues), wrap_message(List.last(parts), repo, issues, Keyword.get(opts, :wrap, :pre))},
      else: {replace_issue_references(List.first(parts), repo, issues), nil}
    end
  end

  @spec commit_line_reviews(Repo.t, GitCommit.t) :: CommitLineReview.t | nil
  def commit_line_reviews(repo, commit) do
    ReviewQuery.commit_line_reviews(repo, commit)
  end

  def commit_gpg_key(agent, %GitCommit{} = commit) do
    case GitAgent.commit_gpg_signature(agent, commit) do
      {:ok, gpg_sig} ->
        gpg_sig
        |> GPGKey.decode!()
        |> GPGKey.parse!()
        |> get_in([:sig, :sub_pack, :issuer])
        |> GPGKeyQuery.by_key_id()
      {:error, _reason} -> nil
    end
  end

  @spec revision_oid(GitAgent.git_revision) :: binary
  def revision_oid(%{oid: oid} = _object), do: oid_fmt(oid)

  @spec revision_branch?(GitAgent.git_revision) :: boolean
  def revision_branch?(%GitRef{type: :branch} = _revision), do: true
  def revision_branch?(_revision), do: false

  @spec revision_name(GitAgent.git_revision) :: binary
  def revision_name(%GitCommit{oid: oid} = _object), do: oid_fmt_short(oid)
  def revision_name(%GitRef{name: name} = _object), do: name
  def revision_name(%GitTag{name: name} = _object), do: name

  @spec revision_type(GitAgent.git_revision) :: atom
  def revision_type(%GitCommit{} = _object), do: :commit
  def revision_type(%GitTag{} = _object), do: :tag
  def revision_type(%GitRef{type: type} = _object), do: type

  @spec revision_href(Plug.Conn.t, GitAgent.git_revision | atom) :: binary
  def revision_href(conn, revision_type) when is_atom(revision_type), do: Routes.codebase_path(conn, revision_type, conn.path_params["user_login"], conn.path_params["repo_name"])
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
    %{repo: repo, tree_path: tree_path} = conn.assigns
    case action_name(conn) do
      :show -> Routes.codebase_path(conn, :tree, repo.owner, repo, "__rev__", tree_path)
      :create -> Routes.codebase_path(conn, :new, repo.owner, repo, "__rev__", tree_path)
      :update -> Routes.codebase_path(conn, :edit, repo.owner, repo, "__rev__", tree_path)
      :delete -> Routes.codebase_path(conn, :confirm_delete, repo.owner, repo, "__rev__", tree_path)
      action -> Routes.codebase_path(conn, action, repo.owner, repo, "__rev__", tree_path)
    end
  end

  @spec tree_entries(GitAgent.agent, GitTree.t) :: [GitTreeEntry.t]
  def tree_entries(agent, tree) do
    case GitAgent.tree_entries(agent, tree) do
      {:ok, entries} -> entries
      {:error, _reason} -> []
    end
  end

  @spec tree_readme(GitAgent.agent, GitTree.t) :: binary | nil
  def tree_readme(agent, tree) do
    with {:ok, entry} <- GitAgent.tree_entry_by_path(agent, tree, "README.md"),
         {:ok, blob} <- GitAgent.tree_entry_target(agent, entry),
         {:ok, content} <- GitAgent.blob_content(agent, blob) do
      markdown_safe(content)
    else
      {:error, _reason} -> nil
    end
  end

  @spec diff_stats(GitAgent.agent, GitDiff.t) :: map | nil
  def diff_stats(agent, diff) do
    case GitAgent.diff_stats(agent, diff) do
      {:ok, stats} -> stats
      {:error, _reason} -> nil
    end
  end

  @spec diff_deltas(GitAgent.agent, GitDiff.t) :: [map] | nil
  def diff_deltas(agent, diff) do
    case GitAgent.diff_deltas(agent, diff) do
      {:ok, deltas} -> deltas
      {:error, _reason} -> []
    end
  end

  @spec diff_deltas_with_reviews(Repo.t, GitAgent.agent, GitCommit.t | [CommitLineReview.t], GitDiff.t) :: [map] | nil
  def diff_deltas_with_reviews(repo, agent, %GitCommit{} = commit, diff), do: diff_deltas_with_reviews(repo, agent, ReviewQuery.commit_line_reviews(repo, commit), diff)
  def diff_deltas_with_reviews(_repo, agent, line_reviews, diff) when is_list(line_reviews) do
    Enum.map(diff_deltas(agent, diff), fn delta ->
      reviews = Enum.filter(line_reviews, &(&1.blob_oid in [delta.old_file.oid, delta.new_file.oid]))
      Enum.reduce(reviews, delta, fn review, delta ->
        update_in(delta.hunks, fn hunks ->
          List.update_at(hunks, review.hunk, &attach_review_to_delta_line(&1, review.line, review))
        end)
      end)
    end)
  end

  @spec diff_deltas_with_comments(Repo.t, GitAgent.agent, GitCommit.t | [CommitLineReview.t], GitDiff.t) :: [map] | nil
  def diff_deltas_with_comments(repo, agent, %GitCommit{} = commit, diff), do: diff_deltas_with_comments(repo, agent, ReviewQuery.commit_line_reviews(repo, commit, preload: [comments: :author]), diff)
  def diff_deltas_with_comments(_repo, agent, line_reviews, diff) when is_list(line_reviews) do
    Enum.map(diff_deltas(agent, diff), fn delta ->
      reviews = Enum.filter(line_reviews, &(&1.blob_oid in [delta.old_file.oid, delta.new_file.oid]))
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

  @spec batch_commits(Repo.t, GitAgent.t, Enumerable.t) :: [{GitCommit.t, User.t | map, boolean, non_neg_integer}]
  def batch_commits(repo, agent, commits) do
    batch_commits_comments_count(repo, agent, commits)
  end

  @spec batch_branches(GitAgent.agent, Enumerable.t) :: [{GitRef.t, {GitCommit.t, User.t | map}}]
  def batch_branches(agent, references_commits) do
    {references, commits} = Enum.unzip(references_commits)
    commits_authors = batch_commits_authors(agent, commits)
    Enum.zip(references, commits_authors)
  end

  @spec batch_tags(GitAgent.agent, Enumerable.t) :: [{GitRef.t | GitTag.t, {GitCommit.t, User.t | map}}]
  def batch_tags(agent, tags_commits) do
    {tags, commits} = Enum.unzip(tags_commits)
    authors = Enum.map(tags_commits, &fetch_author(agent, &1))
    users = query_users(authors)
    Enum.zip(tags, Enum.map(Enum.zip(commits, authors), &zip_author(&1, users)))
  end

  @spec sort_revisions_by_timestamp(GitAgent.agent, Enumerable.t) :: [{GitRef.t | GitTag.t, GitCommit.t}]
  def sort_revisions_by_timestamp(agent, revisions) do
    commits = Enum.map(revisions, &fetch_commit(agent, &1))
    Enum.sort_by(Enum.zip(revisions, commits), &commit_timestamp(agent, elem(&1, 1)), &compare_timestamps/2)
  end

  @spec sort_tree_entries_by_name(Enumerable.t) :: [{GitTreeEntry.t, GitCommit.t}]
  def sort_tree_entries_by_name(tree_entries_commits) do
    Enum.sort_by(tree_entries_commits, fn {tree_entry, _commit} -> tree_entry.name end)
  end

  @spec chunk_by_timestamp(GitAgent.agent, Enumerable.t) :: Enumerable.t
  def chunk_by_timestamp(agent, commits) do
    agent
    |> chunk_batched_commits_by_timestamp(commits)
    |> order_commits_chunks()
  end

  @spec find_issue_references(binary, Repo.t) :: [Issue.t]
  def find_issue_references(content, repo) do
    numbers =
      ~r/\B#([0-9]+)\b/
      |> Regex.scan(content, capture: :all_but_first)
      |> List.flatten()
      |> Enum.map(&String.to_integer/1)
      |> Enum.uniq()
    unless Enum.empty?(numbers),
      do: IssueQuery.repo_issues(repo, numbers: numbers),
    else: []
  end

  @spec replace_issue_references(binary, Repo.t, [Issue.t]) :: binary
  def replace_issue_references(content, _repo, []), do: content
  def replace_issue_references(content, repo, issues) do
    indexes = Regex.scan(~r/\B(#[0-9]+)\b/, content, capture: :all_but_first, return: :index)
    {content, rest, _offset} =
      Enum.reduce(List.flatten(indexes), {[], content, 0}, fn {idx, len}, {acc, rest, offset} ->
        ofs = idx-offset
        <<head::binary-size(ofs), rest::binary>> = rest
        <<match::binary-size(len), rest::binary>> = rest
        "#" <> number = match
        number = String.to_integer(number)
        if issue = Enum.find(issues, &(&1.repo_id == repo.id && &1.number == number)),
          do: {acc ++ [head, link(match, to: Routes.issue_path(GitGud.Web.Endpoint, :show, repo.owner, repo, issue))], rest, idx+len},
        else: {acc ++ [head, match], rest, idx+len}
      end)
    List.flatten(content, [rest])
  end

  @spec title(atom, map) :: binary
  def title(:show, %{repo: repo}) do
    if desc = repo.description,
      do: "#{repo.owner.login}/#{repo.name}: #{desc}",
    else: "#{repo.owner.login}/#{repo.name}"
  end

  def title(action, %{repo: repo}) when action in [:new, :create], do: "New file · #{repo.owner.login}/#{repo.name}"
  def title(action, %{repo: repo, tree_path: path}) when action in [:edit, :update], do: "Edit #{Path.join(path)} · #{repo.owner.login}/#{repo.name}"
  def title(:branches, %{repo: repo}), do: "Branches · #{repo.owner.login}/#{repo.name}"
  def title(:tags, %{repo: repo}), do: "Tags · #{repo.owner.login}/#{repo.name}"
  def title(:commit, %{repo: repo, agent: agent, commit: commit}), do: "#{commit_message_title(agent, commit)} · #{repo.owner.login}/#{repo.name}@#{oid_fmt_short(commit.oid)}"
  def title(:tree, %{repo: repo, revision: rev, tree_path: []}), do: "#{repo.owner.login}/#{repo.name} at #{Param.to_param(rev)}"
  def title(:tree, %{repo: repo, revision: rev, tree_path: path}), do: "#{Path.join(path)} at #{Param.to_param(rev)} · #{repo.owner.login}/#{repo.name}"
  def title(:blob, %{repo: repo, revision: rev, tree_path: path}), do: "#{Path.join(path)} at #{Param.to_param(rev)} · #{repo.owner.login}/#{repo.name}"
  def title(:history, %{repo: repo, revision: rev, tree_path: []}), do: "Commits at #{Param.to_param(rev)} · #{repo.owner.login}/#{repo.name}"
  def title(:history, %{repo: repo, revision: rev, tree_path: path}), do: "Commits at #{Param.to_param(rev)} · #{repo.owner.login}/#{repo.name}/#{Path.join(path)}"

  #
  # Helpers
  #

  defp batch_commits_authors(agent, commits) do
    authors = Enum.map(commits, &fetch_author(agent, &1))
    users = query_users(authors)
    Enum.map(Enum.zip(commits, authors), &zip_author(&1, users))
  end

  defp batch_commits_committers(agent, commits) do
    authors = Enum.map(commits, &fetch_author(agent, &1))
    authors_emails = Enum.map(authors, &(&1.email))
    all_committers = Map.new(commits, &{&1.oid, fetch_committer(agent, &1)})
    committers = Enum.filter(all_committers, fn {_oid, committer} -> committer.email in authors_emails end)
    committers = Enum.into(committers, %{})
    users = query_users(authors ++ Map.values(committers))
    commits
    |> Enum.zip(authors)
    |> Enum.map(fn {commit, author} -> {commit, author, Map.get(committers, commit.oid, all_committers[commit.oid] || author)} end)
    |> Enum.map(&zip_author(&1, users))
  end

  defp batch_commits_gpg_sign(agent, commits) do
    batch = batch_commits_committers(agent, commits)
    commits = Enum.filter(batch, fn
      {_commit, _author, %User{}} -> true
      {_commit, _author, _committer} -> false
    end)
    commits_gpg_key_ids = Enum.map(commits, fn {commit, _author, _committer} ->
      case GitAgent.commit_gpg_signature(agent, commit) do
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
    commits_gpg_key_ids = Enum.reject(commits_gpg_key_ids, &is_nil/1)
    commits_gpg_key_ids = Enum.into(commits_gpg_key_ids, %{})
    gpg_keys =
      commits_gpg_key_ids
      |> Map.values()
      |> Enum.uniq()
      |> GPGKeyQuery.by_key_id()
    gpg_map = Map.new(commits_gpg_key_ids, fn {oid, gpg_key_id} ->
      {oid, Enum.find(gpg_keys, &(binary_part(&1.key_id, 20, -8) == gpg_key_id))}
    end)
    Enum.map(batch, fn
      {commit, author, %User{} = committer} ->
        {commit, author, committer, gpg_map[commit.oid]}
      {commit, author, committer} ->
        {commit, author, committer, nil}
    end)
  end

  defp batch_commits_comments_count(repo, agent, commits) do
    aggregator = Map.new(ReviewQuery.commit_comment_count(repo, commits))
    Enum.map(batch_commits_gpg_sign(agent, commits), fn {commit, author, committer, gpg_key} -> {commit, author, committer, gpg_key, aggregator[commit.oid] || 0} end)
  end

  defp fetch_commit(agent, obj) do
    case GitAgent.peel(agent, obj, :commit) do
      {:ok, commit} -> commit
      {:error, _reason} -> nil
    end
  end

  defp fetch_author(agent, %GitRef{} = reference) do
    case GitAgent.peel(agent, reference) do
      {:ok, object} ->
        fetch_author(agent, object)
      {:error, _reason} -> nil
    end
  end

  defp fetch_author(agent, %GitCommit{} = commit) do
    case GitAgent.commit_author(agent, commit) do
      {:ok, sig} -> sig
      {:error, _reason} -> nil
    end
  end

  defp fetch_author(agent, %GitTag{} = tag) do
    case GitAgent.tag_author(agent, tag) do
      {:ok, sig} -> sig
      {:error, _reason} -> nil
    end
  end

  defp fetch_author(agent, {%GitRef{} = _reference, commit}) do
    fetch_author(agent, commit)
  end

  defp fetch_author(agent, {%GitTag{} = tag, _commit}) do
    fetch_author(agent, tag)
  end

  defp fetch_committer(agent, %GitRef{} = reference) do
    case GitAgent.peel(agent, reference, :commit) do
      {:ok, commit} ->
        fetch_committer(agent, commit)
      {:error, _reason} -> nil
    end
  end

  defp fetch_committer(agent, %GitTag{} = tag) do
    case GitAgent.peel(agent, tag, :commit) do
      {:ok, commit} ->
        fetch_committer(agent, commit)
      {:error, _reason} -> nil
    end
  end

  defp fetch_committer(agent, %GitCommit{} = commit) do
    case GitAgent.commit_committer(agent, commit) do
      {:ok, sig} -> sig
      {:error, _reason} -> nil
    end
  end

  defp fetch_committer(agent, {%GitRef{} = _reference, commit}) do
    fetch_committer(agent, commit)
  end

  defp fetch_timestamp(agent, %GitCommit{} = commit) do
    case GitAgent.commit_timestamp(agent, commit) do
      {:ok, timestamp} -> timestamp
      {:error, _reason} -> nil
    end
  end

  defp find_commit_timestamp({timestamp, _}, timestamp), do: true
  defp find_commit_timestamp({_, _}, _), do: false

  defp chunk_batched_commits_by_timestamp(agent, commits) do
    Enum.reduce(commits, [], fn {commit, _author, _committer, _gpg_key, _comment_count} = tuple, acc ->
      timestamp = DateTime.to_date(fetch_timestamp(agent, commit))
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

  defp wrap_message(content, repo, issues, :pre) do
    content = String.trim(content)
    if content != "", do: content_tag(:pre, replace_issue_references(String.trim(content), repo, issues))
  end

  defp wrap_message(content, repo, issues, :br) do
    content = String.trim(content)
    if content != "" do
      content
      |> String.split("\n\n", trim: true)
      |> Enum.map(&content_tag(:p, wrap_paragraph(&1, repo, issues)))
    end
  end

  defp wrap_message(content, repo, issues, max_line_length) do
    content = String.trim(content)
    if content != "" do
      content
      |> String.split("\n\n", trim: true)
      |> Enum.map(&content_tag(:p, wrap_paragraph(&1, repo, issues, max_line_length)))
    end
  end

  defp wrap_paragraph(content, repo, issues) do
    content = String.trim(content)
    if content != "" do
      content
      |> String.split("\n", trim: true)
      |> Enum.map(&replace_issue_references(&1, repo, issues))
      |> Enum.intersperse(tag(:br))
    end
  end

  defp wrap_paragraph(content, _repo, _issues, max_line_length) do
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
