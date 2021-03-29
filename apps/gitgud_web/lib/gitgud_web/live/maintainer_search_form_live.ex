defmodule GitGud.Web.MaintainerSearchFormLive do
  @moduledoc """
  Live view responsible for rendering forms to add repository maintainers.
  """

  use GitGud.Web, :live_view

  alias GitGud.UserQuery
  alias GitGud.RepoQuery

  import Ecto.Changeset

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
      |> assign_new(:changeset, &changeset/0)
      |> assign(active: false, search_results: [], trigger_submit: false)
    }
  end

  @impl true
  def handle_event("search", %{"maintainer" => maintainer_params}, socket) do
    changeset = changeset(maintainer_params, socket.assigns.search_results, socket.assigns.repo.maintainers)
    if search = get_change(changeset, :user_login) do
      search_results = UserQuery.search(search, viewer: socket.assigns.current_user)
      search_results = Enum.reject(search_results, &(&1 in socket.assigns.repo.maintainers))
      {:noreply, assign(socket, active: search != "", changeset: changeset, search_results: search_results)}
    else
      {:noreply, assign(socket, active: false, changeset: changeset, search_results: [])}
    end
  end

  def handle_event("submit", %{"maintainer" => maintainer_params}, socket), do: trigger_submit_form(socket, maintainer_params)
  def handle_event("select", maintainer_params, socket), do: trigger_submit_form(socket, maintainer_params)

  #
  # Helpers
  #

  defp changeset(params \\ %{}, available_users \\ [], rejected_users \\ []) do
    types = %{user_login: :string}
    {%{}, types}
    |> cast(params, Map.keys(types))
    |> validate_required([:user_login])
    |> validate_login(available_users, rejected_users)
  end

  defp validate_login(changeset, available_users, rejected_users) do
    user_login = get_change(changeset, :user_login)
    cond do
      is_nil(user_login) ->
        changeset
      Enum.find(available_users, &(&1.login == user_login)) ->
        changeset
      Enum.find(rejected_users, &(&1.login == user_login)) ->
        add_error(changeset, :user_login, "has already been taken")
      true ->
        add_error(changeset, :user_login, "invalid")
    end
  end

  defp trigger_submit_form(socket, maintainer_params) do
    changeset = changeset(maintainer_params, socket.assigns.search_results, socket.assigns.repo.maintainers)
    case apply_action(changeset, :insert) do
      {:ok, _maintainer} ->
        {:noreply, assign(socket, active: false, changeset: changeset, trigger_submit: true)}
      {:error, changeset} ->
        {:noreply, assign(socket, active: false, changeset: changeset)}
    end
  end
end
