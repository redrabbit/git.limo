defmodule GitGud.Web.CommentThreadChannel do
  @moduledoc false
  use GitGud.Web, :channel

  def join("issue:" <> _issue, _params, socket) do
    send(self(), :after_join)
    {:ok, socket}
  end

  def join("commit_review:" <> _commit_review, _params, socket) do
    send(self(), :after_join)
    {:ok, socket}
  end

  def join("commit_line_review:" <> _commit_line_review, _params, socket) do
    send(self(), :after_join)
    {:ok, socket}
  end

  def handle_info(:after_join, socket) do
    push(socket, "presence_state", Presence.list(socket))
    case Presence.track(socket, socket.assigns.current_user.id, %{typing: false}) do
      {:ok, _presence} ->
        {:noreply, socket}
      {:error, reason} ->
        {:stop, reason}
    end
  end

  def handle_in("start_typing", _params, socket) do
    case Presence.update(socket, socket.assigns.current_user.id, &Map.put(&1, :typing, true)) do
      {:ok, _presence} ->
        {:noreply, socket}
      {:error, reason} ->
        {:stop, reason}
    end
  end

  def handle_in("stop_typing", _params, socket) do
    case Presence.update(socket, socket.assigns.current_user.id, &Map.put(&1, :typing, false)) do
      {:ok, _presence} ->
        {:noreply, socket}
      {:error, reason} ->
        {:stop, reason}
    end
  end
end
