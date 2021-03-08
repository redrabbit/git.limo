defmodule GitGud.Web.GlobalSearchLive do
  use GitGud.Web, :live_view

  alias GitGud.User
  alias GitGud.Repo
  alias GitGud.UserQuery
  alias GitGud.RepoQuery

  #
  # Callbacks
  #

  def mount(_params, session, socket) do
    socket = assign_new(socket, :current_user, fn -> if user_id = session["user_id"], do: UserQuery.by_id(user_id) end)
    socket = assign(socket, search: "", search_results: [])
    {:ok, socket}
  end

  def handle_event("search", %{"key" => key, "value" => search}, socket) do
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
