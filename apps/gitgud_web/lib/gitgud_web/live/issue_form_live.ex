defmodule GitGud.Web.IssueFormLive do
  use GitGud.Web, :live_view

  alias GitGud.User
  alias GitGud.Repo
  alias GitGud.Issue
  alias GitGud.Comment

  alias GitGud.RepoQuery

  #
  # Callbacks
  #

  @impl true
  def mount(_, %{"repo_id" => repo_id} = session, socket) do
    {
      :ok,
      socket
      |> authenticate(session)
      |> assign_new(:repo, fn -> RepoQuery.by_id(repo_id, preload: :issue_labels) end)
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


  defp assign_changeset(socket) do
    assign_new(socket, :changeset, fn ->
      changeset(socket.assigns.repo, current_user(socket))
    end)
  end

  defp changeset(%Repo{id: repo_id}, %User{id: author_id}, params \\ %{}) do
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
