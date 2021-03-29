defmodule GitGud.Web.CommentFormLive do
  @moduledoc """
  Live component responsible for rendering comment forms.
  """

  use GitGud.Web, :live_component

  alias GitGud.Comment

  @impl true
  def update(assigns, socket) do
    {form_opts, assigns} = Map.split(assigns, [:phx_change, :phx_submit, :phx_target])
    {
      :ok,
      socket
      |> assign(assigns)
      |> assign_tab()
      |> assign_changeset()
      |> assign_form_opts(form_opts)
      |> assign_minimized()
    }
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    tab = String.to_atom(tab)
    case tab do
      :editor ->
        {:noreply, assign(socket, tab: tab)}
      :preview ->
        {:noreply, assign(socket, tab: tab, markdown_preview: markdown_changeset(socket.assigns.changeset, Map.take(socket.assigns, [:repo, :agent])))}
    end
  end

  def handle_event("expand", _params, socket) do
    {:noreply, assign(socket, :minimized, false)}
  end

  #
  # Helpers
  #

  defp assign_tab(socket), do: assign(socket, :tab, :editor)

  defp assign_changeset(socket) when is_map_key(socket.assigns, :changeset), do: socket
  defp assign_changeset(socket), do: assign(socket, :changeset, Comment.changeset(socket.assigns[:comment] || %Comment{}))

  defp assign_form_opts(socket, _form_opts) when is_map_key(socket.assigns, :form_opts), do: socket
  defp assign_form_opts(socket, form_opts), do: assign(socket, :form_opts, Keyword.new(form_opts))

  defp assign_minimized(socket) when is_map_key(socket.assigns, :minimized), do: socket
  defp assign_minimized(socket), do: assign(socket, :minimized, socket.assigns.changeset.data.__meta__.state == :built)

  defp markdown_changeset(changeset, opts) do
    changeset
    |> Ecto.Changeset.get_field(:body)
    |> markdown_safe(opts)
  end
end
