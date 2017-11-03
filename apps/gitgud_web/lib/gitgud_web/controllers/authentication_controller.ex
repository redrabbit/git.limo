defmodule GitGud.Web.AuthenticationController do
  @moduledoc """
  Module responsible for bearer token authentication.
  """

  use GitGud.Web, :controller

  import GitGud.Web.AuthenticationPlug, only: [generate_token: 1]

  alias GitGud.User

  action_fallback GitGud.Web.FallbackController

  @doc """
  Creates a new bearer token for the given user credentials.
  """
  @spec create(Plug.Conn.t, map) :: Plug.Conn.t
  def create(conn, %{"username" => username, "password" => password} = _params) do
    if user = User.check_credentials(username, password) do
      render(conn, "token.json", token: generate_token(user.id))
    else
      {:error, :unauthorized}
    end
  end
end
