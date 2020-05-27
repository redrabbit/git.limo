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

  @spec index(Plug.Conn.t, map) :: Plug.Conn.t
  def index(conn, %{"user_login" => user_login, "repo_name" => repo_name} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn), preload: :issue_labels) do
      query = map_search_query(conn.query_params["q"] || "")
      query_opts = Keyword.merge(Map.to_list(query), preload: [:author, :labels], order_by: [desc: :number])
      issues = IssueQuery.repo_issues_with_comments_count(repo, query_opts)
      render(conn, "index.html", repo: repo, issues: issues, q: query)
    end || {:error, :not_found}
  end

  @spec show(Plug.Conn.t, map) :: Plug.Conn.t
  def show(conn, %{"user_login" => user_login, "repo_name" => repo_name, "number" => issue_number} = _params) do
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn)) do
      if issue = IssueQuery.repo_issue(repo, String.to_integer(issue_number), viewer: current_user(conn)) do
        render(conn, "show.html", repo: repo, issue: issue)
      end
    end || {:error, :not_found}
  end

  @doc """
  Renders a repository creation form.
  """
  @spec new(Plug.Conn.t, map) :: Plug.Conn.t
  def new(conn, %{"user_login" => user_login, "repo_name" => repo_name} = _params) do
    user = current_user(conn)
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn), preload: :issue_labels) do
      if verified?(user),
        do: render(conn, "new.html", repo: repo, changeset: Issue.changeset(%Issue{comments: [%Comment{}]})),
      else: {:error, :unauthorized}
    end || {:error, :not_found}
  end

  @doc """
  Creates a new repository.
  """
  @spec create(Plug.Conn.t, map) :: Plug.Conn.t
  def create(conn, %{"user_login" => user_login, "repo_name" => repo_name, "issue" => issue_params} = _params) do
    user = current_user(conn)
    if repo = RepoQuery.user_repo(user_login, repo_name, viewer: current_user(conn), preload: :issue_labels) do
      if verified?(user) do
        issue_params = Map.merge(issue_params, %{"repo_id" => repo.id, "author_id" => user.id})
        issue_params = Map.update(issue_params, "labels", [], fn label_ids_str ->
          Enum.map(label_ids_str, fn label_id_str ->
            label_id = String.to_integer(label_id_str)
            Enum.find(repo.issue_labels, &(&1.id == label_id))
          end)
        end)
        case Issue.create(issue_params) do
          {:ok, issue} ->
            conn
            |> put_flash(:info, "Issue ##{issue.number} created.")
            |> redirect(to: Routes.issue_path(conn, :show, user_login, repo_name, issue.number))
          {:error, changeset} ->
            conn
            |> put_flash(:error, "Something went wrong! Please check error(s) below.")
            |> put_status(:bad_request)
            |> render("new.html", repo: repo, changeset: %{changeset|action: :insert})
        end
      end || {:error, :unauthorized}
    end || {:error, :not_found}
  end

  #
  # Helpers
  #


  defp map_search_query(str) do
    {params, search} = Enum.reduce(split_search_query(str), {%{}, []}, &map_search_query_word/2)
    params
    |> Map.put_new(:status, [:open])
    |> Map.put_new(:labels, [])
    |> Map.put(:search, Enum.reverse(search))
  end

  defp map_search_query_word("is:" <> status, {params, search}) do
    status = String.to_atom(status)
    {Map.update(params, :status, [status], &(&1 ++ [status])), search}
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
