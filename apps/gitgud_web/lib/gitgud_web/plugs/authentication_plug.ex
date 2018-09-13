defmodule GitGud.Web.AuthenticationPlug do
  @moduledoc """
  `Plug` providing support for multiple authentication methods.
  """

  @behaviour Plug

  import Plug.Conn
  import Phoenix.Controller, only: [render: 3]

  alias GitGud.User
  alias GitGud.UserQuery

  alias GitGud.Web.ErrorView

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
         {:ok, user_id} <- Phoenix.Token.verify(conn, "bearer", token, max_age: 86400) do
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
      |> render(ErrorView, "401.html")
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
  Returns the current user if `conn` is authenticated.
  """
  @spec current_user(Plug.Conn.t) :: GitGud.User.t | nil
  def current_user(conn), do: conn.assigns[:current_user]

  @doc """
  Generates an authentication token.
  """
  @spec authentication_token(Plug.Conn.t|User.t|pos_integer) :: binary | nil
  def authentication_token(%User{id: user_id} = _context), do: authentication_token(user_id)
  def authentication_token(%Plug.Conn{} = conn) do
    if authenticated?(conn),
      do: Phoenix.Token.sign(GitGud.Web.Endpoint, "bearer", current_user(conn).id),
    else: nil
  end

  def authentication_token(user_id) do
    if is_integer(user_id),
      do: Phoenix.Token.sign(GitGud.Web.Endpoint, "bearer", user_id),
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

  defp authenticate_user(conn, user_id) do
    user = UserQuery.by_id(user_id)
    conn
    |> assign(:current_user, user)
    |> Absinthe.Plug.put_options(context: %{current_user: user})
  end
end
