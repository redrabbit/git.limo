defmodule GitGud.Web.Presence do
  @moduledoc false
  use Phoenix.Presence, otp_app: :gitgud_web, pubsub_server: GitGud.Web.PubSub

# alias GitGud.UserQuery

  #
  # Callbacks
  #

# @impl true
# def fetch(_topic, presences) when map_size(presences) == 0, do: presences
# def fetch(_topic, presences) do
#   users = UserQuery.by_login(Map.keys(presences))
#   for {key, presence} <- presences, into: %{} do
#     user = Enum.find(users, %{}, &(&1.login == key))
#     {key, Map.put(presence, :user, user)}
#   end
# end
end
