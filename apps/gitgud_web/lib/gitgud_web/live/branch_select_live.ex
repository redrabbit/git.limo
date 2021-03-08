defmodule GitGud.Web.BranchSelectLive do
  use GitGud.Web, :live_component

  alias GitRekt.GitAgent
  alias GitRekt.GitRef
  alias GitRekt.GitTag

  import GitGud.Web.CodebaseView, only: [
    revision_name: 1,
    revision_type: 1
  ]

  #
  # Callbacks
  #

  @impl true
  def mount(socket) do
    {:ok, assign(socket, active: false, filter: "")}
  end

  @impl true
  def update(assigns, socket) do
    {
      :ok,
      socket
      |> assign(assigns)
      |> assign_label()
      |> assign_tab()
    }
  end

  @impl true
  def handle_event("toggle_dropdown", _value, socket) do
    socket = assign(socket, active: !socket.assigns.active)
    unless Map.has_key?(socket.assigns, :refs),
      do: {:noreply, assign_refs!(socket)},
    else: {:noreply, socket}
  end

  def handle_event("filter", %{"value" => filter}, socket) do
    {:noreply, assign(socket, :filter, filter)}
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :tab, String.to_atom(tab))}
  end

  #
  # Helpers
  #

  defp assign_label(socket) do
    assign(socket,
      label_type: to_string(revision_type(socket.assigns.revision)),
      label_name: revision_name(socket.assigns.revision)
    )
  end

  defp assign_tab(socket) do
    assign(socket, :tab, resolve_tab(socket.assigns.revision))
  end

  defp assign_refs!(socket) do
    assign(socket, :refs, resolve_references!(socket.assigns.agent))
  end

  defp resolve_tab(%GitRef{type: type}), do: type
  defp resolve_tab(%GitTag{}), do: :tag
  defp resolve_tab(_rev), do: :branch

  defp resolve_references!(agent) do
    case GitAgent.references(agent, with: :commit) do
      {:ok, refs} ->
        refs
        |> Enum.map(&map_reference_timestamp!(agent, &1))
        |> Enum.sort_by(&elem(&1, 1), {:desc, NaiveDateTime})
        |> Enum.map(&elem(&1, 0))
        |> Enum.group_by(&(&1.type))
      {:error, reason} ->
        raise RuntimeError, message: reason
    end
  end

  defp map_reference_timestamp!(agent, {ref, commit}) do
    case GitAgent.commit_timestamp(agent, commit) do
      {:ok, timestamp} ->
        {ref, timestamp}
      {:error, reason} ->
        raise RuntimeError, message: reason
    end
  end
end
