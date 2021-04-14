defmodule GitGud.Web.IssueLabelSelectLive do
  @moduledoc """
  Live component responsible for rendering issue labels drop-down lists.
  """

  use GitGud.Web, :live_component

  #
  # Callbacks
  #

  @impl true
  def mount(socket) do
    {:ok, assign(socket, edit: false, push_ids: [], pull_ids: [])}
  end

  @impl true
  def update(assigns, socket) do
    {
      :ok,
      socket
      |> assign(assigns)
      |> assign_labels()
    }
  end

  @impl true
  def handle_event("toggle_edit", _params, socket) do
    if socket.assigns.edit,
      do: {:noreply, assign(socket, edit: false, push_ids: [], pull_ids: [])},
    else: {:noreply, assign(socket, :edit, true)}
  end

  def handle_event("update_labels", _params, socket) do
    send(self(), {:update_labels, {socket.assigns.push_ids, socket.assigns.pull_ids}})
    {:noreply, assign(socket, edit: false, push_ids: [], pull_ids: [])}
  end

  def handle_event("add_label", %{"id" => label_id}, socket) do
    label_id = String.to_integer(label_id)
    if Enum.find(socket.assigns.labels, &(&1.id == label_id)),
      do: {:noreply, assign(socket, :pull_ids, List.delete(socket.assigns.pull_ids, label_id))},
    else: {:noreply, assign(socket, :push_ids, [label_id|socket.assigns.push_ids])}
  end

  def handle_event("delete_label", %{"id" => label_id}, socket) do
    label_id = String.to_integer(label_id)
    if Enum.find(socket.assigns.labels, &(&1.id == label_id)),
      do: {:noreply, assign(socket, :pull_ids, [label_id|socket.assigns.pull_ids])},
    else: {:noreply, assign(socket, :push_ids, List.delete(socket.assigns.push_ids, label_id))}
  end

  #
  # Helpers
  #

  defp assign_labels(socket) when is_map_key(socket.assigns, :issue), do: assign(socket, :labels, socket.assigns.issue.labels)
  defp assign_labels(socket) when is_map_key(socket.assigns, :labels), do: socket
  defp assign_labels(socket), do: assign(socket, :labels, [])
end
