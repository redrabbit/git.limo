defmodule GitGud.Web.UserProfileController do
  @moduledoc """
  Module responsible for CRUD actions on `GitGud.User`.
  """

  use GitGud.Web, :controller

  alias GitGud.UserQuery

  plug :put_layout, :user_profile_layout

  action_fallback GitGud.Web.FallbackController

  @doc """
  Returns a single repository.
  """
  @spec show(Plug.Conn.t, map) :: Plug.Conn.t
  def show(conn, %{"username" => username} = _params) do
    if user = UserQuery.by_username(username, preload: :repositories),
      do: render(conn, "show.html", user: user),
    else: {:error, :not_found}
  end
end

