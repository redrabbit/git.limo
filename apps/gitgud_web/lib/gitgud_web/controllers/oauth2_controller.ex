defmodule GitGud.Web.OAuth2Controller do
  @moduledoc """
  Module responsible for *OAuth2.0* authentication.
  """

  use GitGud.Web, :controller

  alias GitGud.Auth
  alias GitGud.Email
  alias GitGud.User
  alias GitGud.UserQuery

  alias GitGud.OAuth2.GitHub
  alias GitGud.OAuth2.GitLab

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
    token = client.token.access_token
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
          providers: [%Auth.Provider{
            provider: provider,
            provider_id: user_info.id,
            token: token
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

  defp authorize_url!("github", params), do: GitHub.authorize_url!(params)
  defp authorize_url!("gitlab", params), do: GitLab.authorize_url!(params)
  defp authorize_url!(provider, _params) do
    raise ArgumentError, message: "Invalid OAuth2.0 provider #{inspect provider}"
  end

  defp get_token!("github", params), do: GitHub.get_token!(params)
  defp get_token!("gitlab", params), do: GitLab.get_token!(params)
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
