defmodule GitGud.Web.IssueController do
  @moduledoc """
  Module responsible for CRUD actions on `GitGud.Issue`.
  """

  use GitGud.Web, :controller

  alias GitGud.RepoQuery
  alias GitGud.Issue
  alias GitGud.IssueQuery
  alias GitGud.Comment

  plug :ensure_authenticated when action in [:new, :create]
  plug :put_layout, :repo

  action_fallback GitGud.Web.FallbackController

  @doc """
  Render issues.
  """
  @spec index(Plug.Conn.t, map) :: Plug.Conn.t
  def index(conn, %{"user_login" => user_login, "repo_name" => repo_name} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn), preload: :issue_labels) do
      repo_issue_count = IssueQuery.count_repo_issues_by_status(repo)
      query = map_search_query(conn.query_params["q"] || "")
      query_opts = Keyword.merge(Map.to_list(query), preload: [:author, :labels], order_by: [desc: :number])
      issues = IssueQuery.repo_issues_with_reply_count(repo, query_opts)
      render(conn, "index.html",
        repo: repo,
        repo_open_issue_count: repo_issue_count[:open],
        repo_close_issue_count: repo_issue_count[:close],
        issues: issues,
        q: query
      )
    end || {:error, :not_found}
  end

  @doc """
  Creates a new issue.
  """
  @spec create(Plug.Conn.t, map) :: Plug.Conn.t
  def create(conn, %{"user_login" => user_login, "repo_name" => repo_name, "issue" => issue_params} = _params) do
    user = current_user(conn)
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: user, preload: :issue_labels) do
      if verified?(user) do
        issue_params = Map.merge(issue_params, %{"repo_id" => repo.id, "author_id" => user.id})
        issue_params = Map.put_new(issue_params, "comments", [%Comment{}])
        issue_params = Map.update(issue_params, "labels", [], &map_labels(repo.issue_labels, &1))
        case Issue.create(issue_params) do
          {:ok, issue} ->
            conn
            |> put_flash(:info, "Issue ##{issue.number} created.")
            |> redirect(to: Routes.issue_path(conn, :show, user_login, repo_name, issue.number))
          {:error, _changeset} ->
            conn
            |> put_flash(:error, "Something went wrong! Please check error(s) below.")
            |> redirect(to: Routes.issue_path(conn, :new, user_login, repo_name))
        end
      end || {:error, :unauthorized}
    end || {:error, :not_found}
  end

  #
  # Helpers
  #

  defp map_labels(labels, label_ids_str) do
    Enum.map(label_ids_str, fn label_id_str ->
      label_id = String.to_integer(label_id_str)
      Enum.find(labels, &(&1.id == label_id))
    end)
  end

  defp map_search_query(str) do
    {params, search} = Enum.reduce(split_search_query(str), {%{}, []}, &map_search_query_word/2)
    params
    |> Map.put_new(:status, [:open])
    |> Map.put_new(:labels, [])
    |> Map.put(:search, Enum.reverse(search))
  end

  defp map_search_query_word("is:" <> status, {params, search}) do
    status = String.to_atom(status)
    if status in [:open, :close],
     do: {Map.update(params, :status, [status], &(&1 ++ [status])), search},
   else: {params, search}
  end

  defp map_search_query_word("label:" <> label, {params, search}) do
    {Map.update(params, :labels, [label], &(&1 ++ [label])), search}
  end

  defp map_search_query_word(str, {params, search}), do: {params, [str|search]}

  defp split_search_query(str) do
    str
    |> String.split(~r/\s(?=(?:[^'"`]*(['"`])[^'"`]*\1)*[^'"`]*$)/, trim: true)
    |> List.flatten()
    |> Enum.map(&String.replace(&1, ["'", "\""], ""))
    |> Enum.uniq()
  end
end
