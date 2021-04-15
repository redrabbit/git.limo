defmodule GitGud.Web.IssueEventLive do
  @moduledoc """
  Live component responsible for rendering issue events.
  """

  use GitGud.Web, :live_component

  alias GitGud.UserQuery

  #
  # Callbacks
  #

  @impl true
  def preload(list_of_assigns) do
    cond do
      Enum.all?(list_of_assigns, &Map.has_key?(&1.event, "user")) ->
        list_of_assigns
      true ->
        users = batch_event_users(list_of_assigns)
        Enum.map(list_of_assigns, &put_in(&1, [:event, "user"], Map.fetch!(users, &1.event["user_id"])))
    end
  end

  #
  # Helpers
  #

  defp batch_event_users(list_of_assigns) do
    list_of_assigns
    |> Enum.map(&(&1.event["user_id"]))
    |> Enum.uniq()
    |> UserQuery.by_id()
    |> Map.new(&{&1.id, &1})
  end
end
