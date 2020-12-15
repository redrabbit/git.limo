defmodule GitGud.Web.CodebaseView do
  @moduledoc false
  use GitGud.Web, :view

  alias GitRekt.GitAgent

  alias GitGud.Repo
  alias GitGud.Issue
  alias GitGud.IssueQuery

  alias Phoenix.Param

  alias GitRekt.{GitCommit, GitRef, GitTag}

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
    revision_action = revision_action(conn)
    react_component("branch-select", [repo_id: to_relay_id(repo), oid: revision_oid, name: revision_name, type: revision_type, action: revision_action], [class: "branch-select"], do: [
      content_tag(:p, [class: "button"], do: [
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

  @spec chunk_commits_by_timestamp([{GitCommit.t, map, non_neg_integer}]) :: [{Date, [{GitCommit.t, map, non_neg_integer}]}]
  def chunk_commits_by_timestamp(commits) do
    Enum.reduce(Enum.reverse(commits), [], fn {_commit, commit_info, _comment_count} = tuple, acc ->
      timestamp = DateTime.to_date(commit_info.timestamp)
      if idx = Enum.find_index(acc, &find_commit_timestamp(&1, timestamp)),
        do: List.update_at(acc, idx, fn {timestamp, tuples} -> {timestamp, [tuple|tuples]} end),
      else: [{timestamp, [tuple]}|acc]
    end)
  end

  @spec commit_message_title(binary) :: binary | nil
  def commit_message_title(message) do
    List.first(String.split(message, "\n", trim: true, parts: 2))
  end

  @spec commit_message_body(binary) :: binary | nil
  def commit_message_body(message) do
    List.last(String.split(message, "\n", trim: true, parts: 2))
  end

  @spec commit_message_format(Repo.t, binary, keyword) :: {binary, binary | nil} | nil
  def commit_message_format(repo, message, opts \\ []) do
    issues = find_issue_references(message, repo)
    parts = String.split(message, "\n", trim: true, parts: 2)
    if length(parts) == 2,
      do: {replace_issue_references(List.first(parts), repo, issues), wrap_message(List.last(parts), repo, issues, Keyword.get(opts, :wrap, :pre))},
    else: {replace_issue_references(List.first(parts), repo, issues), nil}
  end

  @spec diff_deltas_with_reviews(Repo.t, [map], [CommitLineReview.t]) :: [map] | nil
  def diff_deltas_with_reviews(_repo, deltas, line_reviews) do
    Enum.map(deltas, fn delta ->
      reviews = Enum.filter(line_reviews, &(&1.blob_oid in [delta.old_file.oid, delta.new_file.oid]))
      Enum.reduce(reviews, delta, fn review, delta ->
        update_in(delta.hunks, fn hunks ->
          List.update_at(hunks, review.hunk, &attach_review_to_delta_line(&1, review.line, review))
        end)
      end)
    end)
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

  @spec revision_action(Plug.Conn.t) :: binary
  def revision_action(conn), do: conn.assigns.breadcrumb.action

  @spec highlight_language_from_path(binary) :: binary
  def highlight_language_from_path(path) do
    highlight_language(Path.extname(path))
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
  def title(:commit, %{repo: repo, commit: commit, commit_info: commit_info}), do: "#{commit_message_title(commit_info.title)} · #{repo.owner.login}/#{repo.name}@#{oid_fmt_short(commit.oid)}"
  def title(:tree, %{repo: repo, revision: rev, tree_path: []}), do: "#{repo.owner.login}/#{repo.name} at #{Param.to_param(rev)}"
  def title(:tree, %{repo: repo, revision: rev, tree_path: path}), do: "#{Path.join(path)} at #{Param.to_param(rev)} · #{repo.owner.login}/#{repo.name}"
  def title(:blob, %{repo: repo, revision: rev, tree_path: path}), do: "#{Path.join(path)} at #{Param.to_param(rev)} · #{repo.owner.login}/#{repo.name}"
  def title(:history, %{repo: repo, revision: rev, tree_path: []}), do: "Commits at #{Param.to_param(rev)} · #{repo.owner.login}/#{repo.name}"
  def title(:history, %{repo: repo, revision: rev, tree_path: path}), do: "Commits at #{Param.to_param(rev)} · #{repo.owner.login}/#{repo.name}/#{Path.join(path)}"

  #
  # Helpers
  #

  defp attach_review_to_delta_line(hunk, line, review) do
    update_in(hunk.lines, fn lines -> List.update_at(lines, line, &Map.put(&1, :review, review)) end)
  end

  defp find_commit_timestamp({timestamp, _}, timestamp), do: true
  defp find_commit_timestamp({_, _}, _), do: false

  for line <- File.stream!(highlight_languages) do
    [language|extensions] = String.split(String.trim(line), ~r/\s/, trim: true)
    for extension <- extensions do
      defp highlight_language("." <> unquote(extension)), do: unquote(language)
    end
  end

  defp highlight_language(_extension), do: "plaintext"

  defp lines_assemble([], _, _, line, acc), do: Enum.reverse([line|acc])
  defp lines_assemble([word|rest], max, line_length, line, acc) do
    if line_length + 1 + String.length(word) > max,
      do: lines_assemble(rest, max, String.length(word), word, [line|acc]),
    else: lines_assemble(rest, max, line_length + 1 + String.length(word), line <> " " <> word, acc)
  end

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
end
