defmodule GitGud.Web.AuthenticationPlug do
  @moduledoc """
  Plug for session-based user authentication support.
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
  def authenticated?(conn), do: !!current_user(conn)

  @doc """
  Returns the current user if `conn` is authenticated.
  """
  @spec current_user(Plug.Conn.t) :: GitGud.User.t | nil
  def current_user(conn), do: conn.assigns[:current_user]

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
      |> render(ErrorView, "401.html")
      |> halt()
    else
      conn
    end
  end

  #
  # Callbacks
  #

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    if user_id = get_session(conn, :user_id),
      do: assign(conn, :current_user, UserQuery.by_id(user_id)),
    else: conn
  end
end
