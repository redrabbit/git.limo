defmodule GitGud.Web.OAuth2Controller do
  @moduledoc """
  Module responsible for *OAuth2.0* authentication.
  """

  use GitGud.Web, :controller

  import GitGud.Web.OAuth2View, only: [provider_name: 1]

  alias GitGud.DB
  alias GitGud.User
  alias GitGud.UserQuery

  alias GitGud.OAuth2.{GitHub, GitLab, Provider}

  plug :ensure_authenticated when action in [:index]
  plug :put_layout, :user_settings when action in [:index]

  action_fallback GitGud.Web.FallbackController


  @doc """
  Renders OAuth2.0 providers.
  """
  @spec index(Plug.Conn.t, map) :: Plug.Conn.t
  def index(conn, _params) do
    user = DB.preload(current_user(conn), [account: :oauth2_providers])
    render(conn, "index.html", user: user)
  end

  @doc """
  Deletes an OAuth2.0 provider.
  """
  @spec delete(Plug.Conn.t, map) :: Plug.Conn.t
  def delete(conn, %{"oauth2" => oauth2_params} = _params) do
    user = DB.preload(current_user(conn), [account: :oauth2_providers])
    oauth2_id = String.to_integer(oauth2_params["id"])
    if oauth2 = Enum.find(user.account.oauth2_providers, &(&1.id == oauth2_id)) do
      oauth2 = Provider.delete!(oauth2)
      conn
      |> put_flash(:info, "OAuth2.0 provider #{provider_name(oauth2.provider)} disconnected.")
      |> redirect(to: Routes.oauth2_path(conn, :index))
    else
      {:error, :bad_request}
    end
  end

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
    cond do
      user = authenticated?(conn) && DB.preload(current_user(conn), account: :oauth2_providers) ->
        case Provider.create(auth_id: user.account.id, provider: provider, provider_id: user_info.id, token: client.token.access_token) do
          {:ok, oauth2} ->
            conn
            |> put_session(:user_id, user.id)
            |> put_flash(:info, "OAuth2.0 provider #{provider_name(oauth2.provider)} connected.")
            |> redirect(to: Routes.oauth2_path(conn, :index))
          {:error, _changeset} ->
            conn
            |> put_status(:bad_request)
            |> put_layout(:user_settings)
            |> put_flash(:error, "Something went wrong!")
            |> render("index.html", user: user)
        end
      user = UserQuery.by_oauth(provider, user_info.id) ->
        conn
        |> put_session(:user_id, user.id)
        |> put_flash(:info, "Welcome #{user.login}.")
        |> redirect(to: Routes.user_path(conn, :show, user))
      true ->
        changeset = User.registration_changeset(%User{}, %{
          login: user_info.login,
          name: user_info.name,
          account: %{oauth2_providers: [%{
            provider: provider,
            provider_id: user_info.id,
            token: client.token.access_token,
            email_token: Phoenix.Token.sign(conn, client.token.access_token, user_info.email)
          }]},
          emails: [%{address: user_info.email}]
        })
        conn
        |> put_layout(:hero)
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
