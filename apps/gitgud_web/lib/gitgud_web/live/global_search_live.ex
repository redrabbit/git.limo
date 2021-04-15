defmodule GitGud.Web.GlobalSearchLive do
  @moduledoc """
  Live view responsible for rendering the global search in the top-level navigation bar.
  """

  use GitGud.Web, :live_view

  alias GitGud.User
  alias GitGud.Repo
  alias GitGud.UserQuery
  alias GitGud.RepoQuery

  #
  # Callbacks
  #

  @impl true
  def mount(_params, session, socket) do
    {
      :ok,
      socket
      |> authenticate_later(session)
      |> assign(search: "", search_results: [])
    }
  end

  @impl true
  def handle_event("search", %{"key" => key, "value" => search}, socket) do
    socket = authenticate(socket)
    cond do
      key == "Enter" ->
        case List.first(socket.assigns.search_results) do
          %User{} = user ->
            {:noreply, redirect(socket, to: Routes.user_path(socket, :show, user))}
          %Repo{} = repo ->
            {:noreply, redirect(socket, to: Routes.codebase_path(socket, :show, repo.owner, repo))}
          nil ->
            {:noreply, socket}
        end
      search != socket.assigns.search ->
        user_results = UserQuery.search(search, viewer: socket.assigns.current_user)
        repo_results = RepoQuery.search(search, viewer: socket.assigns.current_user)
        {:noreply, assign(socket, search: search, search_results: user_results ++ repo_results)}
      true ->
        {:noreply, socket}
    end
  end
end
