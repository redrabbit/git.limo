defmodule GitGud.Web.UserPresence do
  @moduledoc false
  use Phoenix.Presence, otp_app: :gitgud_web, pubsub_server: GitGud.Web.PubSub

  alias GitGud.UserQuery
  alias GitGud.Web.Router.Helpers, as: Routes

  def fetch(_topic, presences) when map_size(presences) == 0, do: presences
  def fetch(_topic, presences) do
    users = UserQuery.by_id(Map.keys(presences))
    for {key, presence} <- presences, into: %{} do
      user = Enum.find(users, %{}, &(&1.id == String.to_integer(key)))
      user_data =
        user
        |> Map.take([:login, :avatar_url])
        |> Map.put(:url, Routes.user_url(GitGud.Web.Endpoint, :show, user))
      {key, Map.put(presence, :user, user_data)}
    end
  end
end
