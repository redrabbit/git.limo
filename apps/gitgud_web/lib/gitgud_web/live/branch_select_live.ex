defmodule GitGud.Web.BranchSelectLive do
  @moduledoc """
  Live component responsible for rendering Git revisions drop-down lists.
  """

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
      |> assign_refs!(assigns)
    }
  end

  @impl true
  def handle_event("toggle_dropdown", _value, socket) when not is_map_key(socket.assigns, :refs) do
    {
      :noreply,
      socket
      |> assign(:active, true)
      |> assign_refs!()
      |> assign_tab()
    }
  end

  def handle_event("toggle_dropdown", _value, socket) when socket.assigns.active do
    {
      :noreply,
      socket
      |> assign(active: false, filter: "")
      |> assign_tab()
    }
  end

  def handle_event("toggle_dropdown", _value, socket) do
    {:noreply, assign(socket, :active, true)}
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
    case revision_type(socket.assigns.revision) do
      :commit ->
        assign(socket, :tab, resolve_tab(Enum.find(socket.assigns[:refs] || [], socket.assigns.revision, &(&1.oid == socket.assigns.commit.oid))))
      revision_type ->
        assign(socket, :tab, revision_type)
    end
  end

  defp assign_refs!(socket, assigns) when assigns.active == true, do: assign_refs!(socket)
  defp assign_refs!(socket, _assigns), do: socket

  defp assign_refs!(socket) do
    {head, refs} = resolve_references!(socket.assigns.agent)
    assign(socket, head: head, refs: refs)
  end

  defp resolve_tab(%GitRef{type: type}), do: type
  defp resolve_tab(%GitTag{}), do: :tag
  defp resolve_tab(_rev), do: :branch

  defp resolve_references!(agent) do
    case GitAgent.transaction(agent, &resolve_references/1) do
      {:ok, {head, refs}} ->
        {head, refs}
      {:error, error} ->
        raise error
    end
  end

  defp resolve_references(agent) do
    case GitAgent.references(agent, with: :commit, target: :commit) do
      {:ok, refs} ->
        case GitAgent.head(agent) do
          {:ok, head} ->
            refs = Enum.to_list(refs)
            head_index = Enum.find_index(refs, &elem(&1, 0) == head)
            {
              :ok,
              {
                head,
                refs
                |> List.delete_at(head_index)
                |> Enum.map(&map_reference_timestamp!(agent, &1))
                |> Enum.sort_by(&elem(&1, 1), {:desc, NaiveDateTime})
                |> Enum.map(&elem(&1, 0))
              }
            }
          {:error, _reason} ->
            {
              :ok,
              {
                nil,
                refs
                |> Enum.map(&map_reference_timestamp!(agent, &1))
                |> Enum.sort_by(&elem(&1, 1), {:desc, NaiveDateTime})
                |> Enum.map(&elem(&1, 0))
              }
            }
        end
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp map_reference_timestamp!(agent, {ref, commit}) do
    case GitAgent.commit_timestamp(agent, commit) do
      {:ok, timestamp} ->
        {ref, timestamp}
      {:error, error} ->
        raise error
    end
  end
end
