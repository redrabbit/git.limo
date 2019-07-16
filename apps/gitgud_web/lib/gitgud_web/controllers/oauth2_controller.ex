defmodule GitGud.Web.OAuth2Controller do
  @moduledoc """
  Module responsible for *OAuth2.0* authentication.
  """

  use GitGud.Web, :controller

  alias GitGud.Auth
  alias GitGud.Email
  alias GitGud.User
  alias GitGud.UserQuery

  alias GitGud.OAuth2.{GitHub, GitLab, Provider}

  plug :put_layout, :hero

  action_fallback GitGud.Web.FallbackController

  @doc """
  Redirects to the providers authorize URL.
  """
  @spec authorize(Plug.Conn.t, map) :: Plug.Conn.t
  def authorize(conn, %{"provider" => provider}) do
    redirect(conn, external: authorize_url!(provider, redirect_uri: Routes.oauth2_url(conn, :callback, provider), state: get_csrf_token()))
  end

  @doc """
  Authenticates user with *OAuth2.0* access token.
  """
  @spec callback(Plug.Conn.t, map) :: Plug.Conn.t
  def callback(conn, %{"provider" => provider, "code" => code}) do
    client = get_token!(provider, code: code, redirect_uri: Routes.oauth2_url(conn, :callback, provider))
    user_info = get_user!(provider, client)
    if user = UserQuery.by_oauth(provider, user_info.id) do
      conn
      |> put_session(:user_id, user.id)
      |> put_flash(:info, "Logged in.")
      |> redirect(to: Routes.user_path(conn, :show, user))
    else
      changeset = User.registration_changeset(%User{
        login: user_info.login,
        name: user_info.name,
        auth: %Auth{
          oauth2_providers: [%Provider{
            provider: provider,
            provider_id: user_info.id,
            token: client.token.access_token
          }]
        },
        emails: [%Email{address: user_info.email}]
      })
      conn
      |> put_view(GitGud.Web.UserView)
      |> render("new.html", changeset: changeset)
    end
  end

  #
  # Helpers
  #

  defp authorize_url!("github", params), do: OAuth2.Client.authorize_url!(GitHub.new(), params)
  defp authorize_url!("gitlab", params), do: OAuth2.Client.authorize_url!(GitLab.new(), Keyword.merge(params, scope: "read_user"))
  defp authorize_url!(provider, _params) do
    raise ArgumentError, message: "Invalid OAuth2.0 provider #{inspect provider}"
  end

  defp get_token!("github", params) do
    client = OAuth2.Client.get_token!(GitHub.new(), params)
    if error_desc = is_nil(client.token.access_token) && client.token.other_params["error_description"] do
      raise OAuth2.Error, reason: error_desc
    end || client
  end

  defp get_token!("gitlab", params), do: OAuth2.Client.get_token!(GitLab.new(), params)
  defp get_token!(provider, _params) do
    raise ArgumentError, message: "Invalid OAuth2.0 provider #{inspect provider}"
  end

  defp get_user!("github", client) do
    response = OAuth2.Client.get!(client, "/user")
    %{
      id: response.body["id"],
      login: response.body["login"],
      name: response.body["name"],
      email: response.body["email"]
    }
  end

  defp get_user!("gitlab", client) do
    response = OAuth2.Client.get!(client, "/user")
    %{
      id: response.body["id"],
      login: response.body["username"],
      name: response.body["name"],
      email: response.body["email"]
    }
  end

  defp get_user!(provider, _client) do
    raise ArgumentError, message: "Invalid OAuth2.0 provider #{inspect provider}"
  end
end
