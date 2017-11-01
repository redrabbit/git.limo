defmodule GitGud.Web.AuthenticationPlug do
  @moduledoc """
  Plug for authenticating API request with bearer token.
  """
  @behaviour Plug

  import Plug.Conn
  import Phoenix.Controller, only: [render: 3]

  alias GitGud.UserQuery
  alias GitGud.Web.ErrorView

  @doc """
  Returns `true` if the given `conn` is authenticated; otherwise returns `false`.
  """
  @spec authenticated?(Plug.Conn.t) :: boolean
  def authenticated?(conn), do: !!conn.assigns[:user]

  @doc """
  Plug ensuring that the request is authenticated.

  If the given `conn` is not `authenticated?/1`, this plug function will preventing further plugs downstream from being
  invoked and return a *401 Unauthenticated* error.
  """
  @spec ensure_authenticated(Plug.Conn.t, keyword) :: Plug.Conn.t
  def ensure_authenticated(conn, _opts) do
    unless authenticated?(conn) do
      conn
      |> put_status(:unauthorized)
      |> render(ErrorView, "401.json")
      |> halt()
    else
      conn
    end
  end

  @spec generate_token(pos_integer) :: binary
  def generate_token(user_id) do
    Phoenix.Token.sign(GitGud.Web.Endpoint, secret_key_base(), user_id)
  end

  #
  # Callbacks
  #

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    salt = secret_key_base()
    token = bearer_token(conn)
    case Phoenix.Token.verify(conn, salt, token, max_age: 86400) do
      {:ok, user_id} -> assign(conn, :user, UserQuery.get(user_id))
      {:error, :invalid} -> conn
      {:error, :missing} -> conn
    end
  end

  #
  # Helpers
  #

  defp bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        token
      [] -> nil
    end
  end

  defp secret_key_base do
    endpoint_config = Application.fetch_env!(:gitgud_web, GitGud.Web.Endpoint)
    Keyword.fetch!(endpoint_config, :secret_key_base)
  end
end
