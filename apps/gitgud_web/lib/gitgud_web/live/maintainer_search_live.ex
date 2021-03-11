defmodule GitGud.Web.MaintainerSearchLive do
  use GitGud.Web, :live_view

  alias GitGud.UserQuery
  alias GitGud.RepoQuery

  #
  # Callbacks
  #

  @impl true
  def mount(_params, %{"repo_id" => repo_id} = session, socket) do
    {
      :ok,
      socket
      |> authenticate(session)
      |> assign_new(:repo, fn -> RepoQuery.by_id(repo_id, preload: :maintainers) end)
      |> assign(selected_user: nil, search: "", search_results: [])
    }
  end

  @impl true
  def handle_event("search", %{"key" => key, "value" => search}, socket) do
    cond do
      socket.assigns.search == "" && key == "Backspace" ->
        {:noreply, assign(socket, :selected_user, nil)}
      socket.assigns.selected_user ->
        {:noreply, assign(socket, search: search)}
      socket.assigns.search != search ->
        user_results = UserQuery.search(search, viewer: socket.assigns.current_user)
        user_results = Enum.reject(user_results, &(&1 in socket.assigns.repo.maintainers))
        {:noreply, assign(socket, search: search, search_results: user_results)}
      true ->
        {:noreply, socket}
    end
  end

  def handle_event("select", %{"login" => user_login}, socket) do
    socket = assign(socket, :selected_user, Enum.find(socket.assigns.search_results, &(&1.login == user_login)))
    socket = assign(socket, search: "", search_results: [])
    {:noreply, socket}
  end
end
