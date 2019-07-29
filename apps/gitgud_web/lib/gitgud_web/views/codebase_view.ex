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

  alias Phoenix.Param

  alias GitRekt.{GitCommit, GitTag, GitRef}

  import Phoenix.HTML, only: [raw: 1]
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
    react_component("branch-select", [repo_id: to_relay_id(repo), oid: revision_oid, name: revision_name, type: revision_type, branch_href: revision_href(conn, :branches), tag_href: revision_href(conn, :tags)], [class: "branch-select"], do: [
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

  @spec breadcrump_action(atom) :: atom
  def breadcrump_action(:blob), do: :tree
  def breadcrump_action(action), do: action

  @spec blob_content(Repo.t, GitAgent.git_blob) :: binary | nil
  def blob_content(repo, blob) do
    case GitAgent.blob_content(repo, blob) do
      {:ok, content} -> content
      {:error, _reason} -> nil
    end
  end

  @spec blob_size(Repo.t, GitAgent.git_blob) :: non_neg_integer | nil
  def blob_size(repo, blob) do
    case GitAgent.blob_size(repo, blob) do
      {:ok, size} -> size
      {:error, _reason} -> nil
    end
  end

  @spec commit_author(Repo.t, Commit.t | GitAgent.git_commit) :: map | nil
  def commit_author(repo, %Commit{} = commit), do: fetch_author(repo, commit)
  def commit_author(repo, commit) do
    case GitAgent.commit_author(repo, commit) do
      {:ok, author} ->
        if user = UserQuery.by_email(author.email),
          do: user,
        else: author
      {:error, _reason} -> nil
    end
  end

  @spec commit_timestamp(Repo.t, Commit.t | GitAgent.git_commit) :: DateTime.t | nil
  def commit_timestamp(_repo, %Commit{} = commit), do: commit.committed_at
  def commit_timestamp(repo, commit) do
    case GitAgent.commit_timestamp(repo, commit) do
      {:ok, timestamp} -> timestamp
      {:error, _reason} -> nil
    end
  end

  @spec commit_message(Repo.t, Commit.t | GitAgent.git_commit) :: binary | nil
  def commit_message(_repo, %Commit{} = commit), do: commit.message
  def commit_message(repo, commit) do
    case GitAgent.commit_message(repo, commit) do
      {:ok, message} -> message
      {:error, _reason} -> nil
    end
  end

  @spec commit_message_title(Repo.t, Commit.t | GitAgent.git_commit) :: binary | nil
  def commit_message_title(repo, commit) do
    if message = commit_message(repo, commit) do
      List.first(String.split(message, "\n", trim: true, parts: 2))
    end
  end

  @spec commit_message_body(Repo.t, Commit.t | GitAgent.git_commit) :: binary | nil
  def commit_message_body(repo, commit) do
    if message = commit_message(repo, commit) do
      List.last(String.split(message, "\n", trim: true, parts: 2))
    end
  end

  @spec commit_message_format(Repo.t, Commit.t | GitAgent.git_commit, keyword) :: {binary, binary | nil} | nil
  def commit_message_format(repo, commit, opts \\ []) do
    if message = commit_message(repo, commit) do
      parts = String.split(message, "\n", trim: true, parts: 2)
      if length(parts) == 2,
        do: {List.first(parts), wrap_message(List.last(parts), Keyword.get(opts, :wrap, :pre))},
      else: {List.first(parts), nil}
    end
  end

  @spec commit_review(Repo.t, Commit.t | GitAgent.git_commit) :: CommitReview.t | nil
  def commit_review(repo, commit) do
    ReviewQuery.commit_review(repo, commit)
  end

  @spec revision_oid(GitAgent.git_object) :: binary
  def revision_oid(%{oid: oid} = _object), do: oid_fmt(oid)

  @spec revision_name(Repo.git_object) :: binary
  def revision_name(%GitCommit{oid: oid} = _object = _object), do: oid_fmt_short(oid)
  def revision_name(%GitRef{name: name} = _object), do: name
  def revision_name(%GitTag{name: name} = _object), do: name

  @spec revision_type(GitAgent.git_object) :: atom
  def revision_type(%GitCommit{} = _object), do: :commit
  def revision_type(%GitTag{} = _object), do: :tag
  def revision_type(%GitRef{type: type} = _object), do: type

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

  @spec tree_entries(Repo.t, GitAgent.git_tree) :: [GitAgent.git_tree_entry]
  def tree_entries(repo, tree) do
    case GitAgent.tree_entries(repo, tree) do
      {:ok, entries} -> entries
      {:error, _reason} -> []
    end
  end

  @spec tree_readme(Repo.t, GitAgent.git_tree) :: binary | nil
  def tree_readme(repo, tree) do
    with {:ok, entry} <- GitAgent.tree_entry_by_path(repo, tree, "README.md"),
         {:ok, blob} <- GitAgent.tree_entry_target(repo, entry),
         {:ok, content} <- GitAgent.blob_content(repo, blob),
         {:ok, html, []} <- Earmark.as_html(content) do
      raw(html)
    else
      {:error, _reason} -> nil
    end
  end

  @spec diff_stats(Repo.t, GitAgent.git_diff) :: map | nil
  def diff_stats(repo, diff) do
    case GitAgent.diff_stats(repo, diff) do
      {:ok, stats} -> stats
      {:error, _reason} -> nil
    end
  end

  @spec diff_deltas(Repo.t, GitAgent.git_diff) :: [map] | nil
  def diff_deltas(repo, diff) do
    case GitAgent.diff_deltas(repo, diff) do
      {:ok, deltas} -> deltas
      {:error, _reason} -> []
    end
  end

  @spec diff_deltas_with_reviews(Repo.t, GitAgent.git_commit, GitAgent.git_diff) :: [map] | nil
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

  @spec diff_deltas_with_comments(Repo.t, GitAgent.git_commit, GitAgent.git_diff) :: [map] | nil
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

  @spec batch_commits(Repo.t, Enumerable.t) :: [{GitAgent.git_commit, User.t | map, boolean, non_neg_integer}]
  def batch_commits(repo, commits) do
    batch_commits_comments_count(repo, commits)
  end

  @spec batch_branches(Repo.t, Enumerable.t) :: [{GitAgent.git_reference, {GitAgent.git_commit, User.t | map}}]
  def batch_branches(repo, references_commits) do
    {references, commits} = Enum.unzip(references_commits)
    commits_authors = batch_commits_authors(repo, commits)
    Enum.zip(references, commits_authors)
  end

  @spec batch_tags(Repo.t, Enumerable.t) :: [{GitAgent.git_reference | GitAgent.git_tag, {GitAgent.git_commit, User.t | map}}]
  def batch_tags(repo, tags_commits) do
    {tags, commits} = Enum.unzip(tags_commits)
    authors = Enum.map(tags_commits, &fetch_author(repo, &1))
    users = query_users(authors)
    Enum.zip(tags, Enum.map(Enum.zip(commits, authors), &zip_author(&1, users)))
  end

  @spec sort_by_timestamp(Repo.t, Enumerable.t) :: [{GitAgent.git_reference | GitAgent.git_tag, GitAgent.git_commit}]
  def sort_by_timestamp(repo, references_or_tags) do
    commits = Enum.map(references_or_tags, &fetch_commit(repo, &1))
    Enum.sort_by(Enum.zip(references_or_tags, commits), &commit_timestamp(repo, elem(&1, 1)), &compare_timestamps/2)
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

  defp batch_commits_gpg_sign(repo, commits) do
    gpg_map = CommitQuery.gpg_signature(repo, commits)
    Enum.map(batch_commits_authors(repo, commits), fn
      {commit, %User{id: user_id} = author} ->
        {commit, author, gpg_map[commit.oid] == user_id}
      {commit, author} ->
        {commit, author, false}
    end)
  end

  defp batch_commits_comments_count(repo, commits) do
    aggregator = Map.new(ReviewQuery.commit_comment_count(repo, commits))
    Enum.map(batch_commits_gpg_sign(repo, commits), fn {commit, author, verified?} -> {commit, author, verified?, aggregator[commit.oid] || 0} end)
  end

  defp fetch_commit(repo, reference) do
    case GitAgent.peel(repo, reference) do
      {:ok, commit} -> commit
      {:error, _reason} -> nil
    end
  end

  defp fetch_author(repo, %GitRef{} = reference) do
    case GitAgent.peel(repo, reference) do
      {:ok, commit} ->
        fetch_author(repo, commit)
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

  defp highlight_language(_extension), do: "nohighlight"

  defp wrap_message(content, :pre) do
    content_tag(:pre, String.trim(content))
  end

  defp wrap_message(content, :br) do
    content
    |> String.split("\n\n", trim: true)
    |> Enum.map(&content_tag(:p, wrap_paragraph(&1)))
  end

  defp wrap_message(content, max_line_length) do
    content
    |> String.split("\n\n", trim: true)
    |> Enum.map(&content_tag(:p, wrap_paragraph(&1, max_line_length)))
  end

  defp wrap_paragraph(content) do
    content
    |> String.split("\n", trim: true)
    |> Enum.intersperse(tag(:br))
  end

  defp wrap_paragraph(content, max_line_length) do
    [word|rest] = String.split(content, ~r/\s+/, trim: true)
    Enum.intersperse(lines_assemble(rest, max_line_length, String.length(word), word, []), tag(:br))
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

  defp zip_author({parent, author}, users) do
    {parent, Map.get(users, author.email, author)}
  end
end
