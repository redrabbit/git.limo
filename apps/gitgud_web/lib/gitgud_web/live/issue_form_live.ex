defmodule GitGud.Web.IssueFormLive do
  use GitGud.Web, :live_view

  alias GitGud.DB
  alias GitGud.DBQueryable

  alias GitGud.User
  alias GitGud.Repo
  alias GitGud.Issue
  alias GitGud.Comment

  alias GitGud.RepoQuery

  #
  # Callbacks
  #

  @impl true
  def mount(%{"user_login" => user_login, "repo_name" => repo_name}, session, socket) do
    {
      :ok,
      socket
      |> authenticate(session)
      |> assign_repo!(user_login, repo_name)
      |> assign_repo_open_issue_count()
      |> assign_page_title()
      |> assign_changeset()
      |> assign(labels: [], trigger_submit: false)
    }
  end

  @impl true
  def handle_event("validate", %{"issue" => issue_params}, socket) do
    changeset = changeset(socket.assigns.repo, current_user(socket), issue_params)
    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("submit", %{"issue" => issue_params}, socket) do
    changeset = changeset(socket.assigns.repo, current_user(socket), issue_params)
    case Ecto.Changeset.apply_action(changeset, :insert) do
      {:ok, _issue} ->
        {:noreply, assign(socket, changeset: changeset, trigger_submit: true)}
      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def handle_event("add_label", %{"id" => label_id}, socket) do
    {:noreply, assign(socket, :labels, [String.to_integer(label_id)|socket.assigns.labels])}
  end

  def handle_event("delete_label", %{"id" => label_id}, socket) do
    {:noreply, assign(socket, :labels, List.delete(socket.assigns.labels, String.to_integer(label_id)))}
  end

  #
  # Helpers
  #


  defp assign_repo!(socket, user_login, repo_name) do
    query = DBQueryable.query({RepoQuery, :user_repo_query}, [user_login, repo_name], viewer: current_user(socket), preload: :issue_labels)
    assign(socket, :repo, DB.one!(query))
  end

  defp assign_repo_open_issue_count(socket) when socket.connected?, do: socket
  defp assign_repo_open_issue_count(socket) do
    assign(socket, :repo_open_issue_count, GitGud.IssueQuery.count_repo_issues(socket.assigns.repo, status: :open))
  end

  defp assign_changeset(socket, params \\ %{}) do
    assign(socket, :changeset, changeset(socket.assigns.repo, current_user(socket), params))
  end

  defp assign_page_title(socket) do
    assign(socket, :page_title, GitGud.Web.IssueView.title(socket.assigns[:live_action], socket.assigns))
  end

  defp changeset(%Repo{id: repo_id}, %User{id: author_id}, params) do
    Issue.changeset(
      %Issue{
        repo_id: repo_id,
        author_id: author_id,
        labels: [],
        comments: [
          %Comment{
            repo_id: repo_id,
            author_id: author_id,
            thread_table: "issues_comments"
          }
        ]
      },
      params
    )
  end
end
