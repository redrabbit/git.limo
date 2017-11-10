defmodule GitGud.Web.AuthenticationView do
  @moduledoc false
  use GitGud.Web, :view

  import GitGud.Web.AuthenticationPlug, only: [token_expiration_time: 0]

  def render("token.json", %{token: token}) do
    %{token: token, expiration_time: token_expiration_time()}
  end
end
