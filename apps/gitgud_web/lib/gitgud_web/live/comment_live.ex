defmodule GitGud.Web.CommentLive do
  use GitGud.Web, :live_component

  alias GitGud.Comment

  @impl true
  def update(assigns, socket) do
    {
      :ok,
      socket
      |> assign(assigns)
      |> assign_changeset()
    }
  end

  @impl true
  def handle_event("toggle_edit", _params, socket) when is_nil(socket.assigns.changeset) do
    {:noreply, assign(socket, :changeset, Comment.changeset(socket.assigns.comment))}
  end

  def handle_event("toggle_edit", _params, socket) do
    {:noreply, assign(socket, :changeset, nil)}
  end

  def handle_event("validate", %{"comment" => comment_params}, socket) do
    {:noreply, assign(socket, :changeset, Comment.changeset(socket.assigns.comment, comment_params))}
  end

  def handle_event("update", %{"comment" => comment_params}, socket) do
    case Comment.update(socket.assigns.comment, current_user(socket), comment_params) do
      {:ok, comment} ->
        send(self(), {:update_comment, comment})
        {:noreply, assign(socket, comment: comment, changeset: nil)}
      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("delete", _params, socket) do
    case Comment.delete(socket.assigns.comment) do
      {:ok, comment} ->
        send(self(), {:delete_comment, comment})
        {:noreply, assign(socket, :comment, comment)}
      {:error, changeset} ->
      {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  #
  # Helpers
  #

  defp assign_changeset(socket) when is_map_key(socket.assigns, :changeset), do: socket
  defp assign_changeset(socket), do: assign(socket, :changeset, nil)
end
