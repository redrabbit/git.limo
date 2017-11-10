defmodule GitGud.Web.AuthenticationPlug do
  @moduledoc """
  Plug for authenticating API requests with bearer token.
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

  @doc """
  Generates a token for the give `user_id`.

  See `Phoenix.Token.sign/4` for more details.
  """
  @spec generate_token(pos_integer, keyword) :: binary
  def generate_token(user_id, opts \\ []) do
    Phoenix.Token.sign(GitGud.Web.Endpoint, secret_key_base(), user_id, opts)
  end

  @doc """
  Returns the default expiration time of a token.
  """
  @spec token_expiration_time() :: integer
  def token_expiration_time do
    86400
  end

  #
  # Callbacks
  #

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, opts) do
    opts = Keyword.put_new(opts, :max_age, token_expiration_time())
    salt = secret_key_base()
    token = bearer_token(conn)
    case Phoenix.Token.verify(GitGud.Web.Endpoint, salt, token, opts) do
      {:ok, user_id} -> assign(conn, :user, UserQuery.get(user_id))
      {:error, :missing} -> conn
      {:error, :invalid} -> conn
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
