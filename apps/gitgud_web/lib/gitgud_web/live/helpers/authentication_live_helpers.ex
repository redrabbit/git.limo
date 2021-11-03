defmodule GitGud.Web.AuthenticationLiveHelpers do
  @moduledoc """
  Conveniences for authentication related tasks in live views.
  """

  alias GitGud.Authorization

  alias GitGud.User
  alias GitGud.UserQuery

  import Phoenix.LiveView

  @doc """
  Authenticates `socket` with `session`.
  """
  @spec authenticate(Phoenix.LiveView.Socket.t, map) :: Phoenix.LiveView.Socket.t
  def authenticate(socket, session) do
    user_id = session["user_id"]
    socket
    |> assign(:current_user_id, user_id)
    |> assign_new( :current_user, fn -> if user_id, do: UserQuery.by_id(user_id) end)
  end

  @doc """
  Prepares `socket` for authenticating later on.
  """
  @spec authenticate_later(Phoenix.LiveView.Socket.t, map) :: Phoenix.LiveView.Socket.t
  def authenticate_later(socket, session) do
    assign(socket, current_user_id: session["user_id"], current_user: nil)
  end

  @doc """
  Authenticates `socket`.
  """
  def authenticate(socket) when is_nil(socket.assigns.current_user) and not is_nil(socket.assigns.current_user_id), do: assign(socket, :current_user, UserQuery.by_id(socket.assigns.current_user_id))
  def authenticate(socket), do: socket

  @doc """
  Returns `true` if the given `socket` is authenticated; otherwise returns `false`.
  """
  @spec authenticated?(Phoenix.LiveView.Socket.t) :: boolean
  def authenticated?(socket), do: !!current_user(socket)

  @doc """
  Returns `true` if the given `conn` is allowed to perform `action` on `resource`; otherwhise returns `false`.
  """
  @spec authorized?(Phoenix.LiveView.Socket.t, any, atom) :: boolean
  def authorized?(%Phoenix.LiveView.Socket{} = socket, resource, action), do: authorized?(current_user(socket), resource, action)
  defdelegate authorized?(user, resource, action), to: Authorization

  @doc """
  Returns `true` if the given `conn` is authenticated with a verified user; otherwise returns `false`.
  """
  @spec verified?(Phoenix.LivewView.Socket.t) :: boolean
  def verified?(%Phoenix.LiveView.Socket{} = socket), do: verified?(current_user(socket))
  defdelegate verified?(user), to: User

  @doc """
  Returns the current user if `conn` is authenticated.
  """
  @spec current_user(Phoenix.LiveView.Socket.t) :: User.t | nil
  def current_user(socket), do: socket.assigns[:current_user]
end
