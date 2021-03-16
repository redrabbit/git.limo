defmodule GitGud.Web.AuthenticationPlug do
  @moduledoc """
  `Plug` providing support for multiple authentication methods.
  """

  @behaviour Plug

  import Plug.Conn

  alias GitGud.Authorization
  alias GitGud.User
  alias GitGud.UserQuery

  @doc """
  `Plug` to authenticate `conn` with either authorization or session tokens.
  """
  @spec authenticate(Plug.Conn.t, keyword) :: Plug.Conn.t
  def authenticate(conn, opts) do
    conn = authenticate_bearer_token(conn, opts)
    unless authenticated?(conn),
       do: authenticate_session(conn, opts),
     else: conn
  end


  @doc """
  `Plug` to authenticate `conn` with session tokens.
  """
  @spec authenticate_session(Plug.Conn.t, keyword) :: Plug.Conn.t
  def authenticate_session(conn, _opts) do
    if user_id = get_session(conn, :user_id),
      do: authenticate_user(conn, user_id),
    else: conn
  end

  @doc """
  `Plug` to authenticate `conn` with authorization tokens.
  """
  @spec authenticate_bearer_token(Plug.Conn.t, keyword) :: Plug.Conn.t
  def authenticate_bearer_token(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, user_id} <- Phoenix.Token.verify(endpoint(conn), "bearer", token, max_age: 86400) do
      authenticate_user(conn, user_id)
    else
      _ ->
        conn
    end
  end

  @doc """
  `Plug` to ensure that the request is authenticated.

  If the given `conn` is not `authenticated?/1`, this prevents further plugs downstream from being
  invoked and returns a *401 Unauthenticated* error.
  """
  @spec ensure_authenticated(Plug.Conn.t, keyword) :: Plug.Conn.t
  def ensure_authenticated(conn, _opts) do
    unless authenticated?(conn) do
      conn
      |> put_status(:unauthorized)
      |> Phoenix.Controller.put_layout(false)
      |> Phoenix.Controller.put_view(GitGud.Web.ErrorView)
      |> Phoenix.Controller.render(:"401")
      |> halt()
    else
      conn
    end
  end

  @doc """
  Returns `true` if the given `conn` is authenticated; otherwise returns `false`.
  """
  @spec authenticated?(Plug.Conn.t) :: boolean
  def authenticated?(conn), do: !!current_user(conn)

  @doc """
  Returns `true` if the given `conn` is allowed to perform `action` on `resource`; otherwhise returns `false`.
  """
  @spec authorized?(Plug.Conn.t, any, atom) :: boolean
  def authorized?(%Plug.Conn{} = conn, resource, action), do: authorized?(current_user(conn), resource, action)
  defdelegate authorized?(user, resource, action), to: Authorization

  @doc """
  Returns `true` if the given `conn` is authenticated with a verified user; otherwise returns `false`.
  """
  @spec verified?(Plug.Conn.t) :: boolean
  def verified?(%Plug.Conn{} = conn), do: verified?(current_user(conn))
  defdelegate verified?(user), to: User

  @doc """
  Returns the current user if `conn` is authenticated.
  """
  @spec current_user(Plug.Conn.t) :: GitGud.User.t | nil
  def current_user(conn), do: conn.assigns[:current_user]

  @doc """
  Generates an authentication token.
  """
  @spec authentication_token(Plug.Conn.t) :: binary | nil
  def authentication_token(%Plug.Conn{} = conn) do
    if authenticated?(conn),
      do: Phoenix.Token.sign(endpoint(conn), "bearer", current_user(conn).id),
    else: nil
  end

  #
  # Callbacks
  #

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, opts), do: authenticate(conn, opts)

  #
  # Helpers
  #

  defp endpoint(conn) do
    if Map.has_key?(conn.private, :phoenix_endpoint),
      do: conn,
    else: GitGud.Web.Endpoint
  end

  defp authenticate_user(conn, user_id) do
    if user = UserQuery.by_id(user_id),
      do: assign(conn, :current_user, user),
    else: conn
  end
end
