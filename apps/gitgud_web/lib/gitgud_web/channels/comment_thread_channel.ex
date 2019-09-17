defmodule GitGud.Web.CommentThreadChannel do
  @moduledoc false
  use GitGud.Web, :channel

  alias GitGud.Web.CommentThreadPresence

  intercept ["presence_diff"]

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
    push(socket, "presence_state", filter_presence(CommentThreadPresence.list(socket), socket.assigns.current_user))
    case CommentThreadPresence.track(socket, socket.assigns.current_user.id, %{typing: false}) do
      {:ok, _presence} ->
        {:noreply, socket}
      {:error, reason} ->
        {:stop, reason}
    end
  end

  def handle_in("start_typing", _params, socket) do
    case CommentThreadPresence.update(socket, socket.assigns.current_user.id, &Map.put(&1, :typing, true)) do
      {:ok, _presence} ->
        {:noreply, socket}
      {:error, reason} ->
        {:stop, reason}
    end
  end

  def handle_in("stop_typing", _params, socket) do
    case CommentThreadPresence.update(socket, socket.assigns.current_user.id, &Map.put(&1, :typing, false)) do
      {:ok, _presence} ->
        {:noreply, socket}
      {:error, reason} ->
        {:stop, reason}
    end
  end

  def handle_out("presence_diff", diff, socket) do
    push(socket, "presence_diff", filter_presence_diff(diff, socket.assigns.current_user))
    {:noreply, socket}
  end

  #
  # Helpers
  #

  def filter_presence(presence, user) do
    presence
    |> Enum.reject(fn {id_str, _data} -> String.to_integer(id_str) == user.id end)
    |> Map.new()
  end

  def filter_presence_diff(diff, user) do
    Map.new(diff, fn {action, presence} -> {action, filter_presence(presence, user)} end)
  end
end
