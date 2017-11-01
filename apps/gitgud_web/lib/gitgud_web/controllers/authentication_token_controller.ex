defmodule GitGud.Web.AuthenticationTokenController do
  @moduledoc """
  Module responsible for bearer token authentication.
  """

  use GitGud.Web, :controller

  import GitGud.Web.AuthenticationPlug, only: [generate_token: 1]

  alias GitGud.User

  action_fallback GitGud.Web.FallbackController

  def create(conn, %{"username" => username, "password" => password}) do
    if user = User.check_credentials(username, password) do
      render(conn, "token.json", token: generate_token(user.id))
    else
      {:error, :unauthorized}
    end
  end
end
