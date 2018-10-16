defmodule GitGud.Web.SSHKeyController do
  @moduledoc """
  Module responsible for CRUD actions on `GitGud.SSHKey`.
  """

  use GitGud.Web, :controller

  alias GitGud.DB
  alias GitGud.SSHKey

  plug :ensure_authenticated
  plug :put_layout, :user_settings

  action_fallback GitGud.Web.FallbackController

  @doc """
  Renders SSH keys.
  """
  @spec index(Plug.Conn.t, map) :: Plug.Conn.t
  def index(conn, _params) do
    user = DB.preload(current_user(conn), :ssh_keys)
    render(conn, "index.html", user: user)
  end

  @doc """
  Renders a creation form for SSH keys.
  """
  @spec new(Plug.Conn.t, map) :: Plug.Conn.t
  def new(conn, _params) do
    changeset = SSHKey.changeset(%SSHKey{})
    render(conn, "new.html", changeset: changeset)
  end

  @doc """
  Creates a new SSH key.
  """
  @spec create(Plug.Conn.t, map) :: Plug.Conn.t
  def create(conn, %{"ssh_key" => key_params} = _params) do
    user = current_user(conn)
    case SSHKey.create(Map.put(key_params, "user_id", user.id)) do
      {:ok, ssh_key} ->
        conn
        |> put_flash(:info, "SSH key '#{ssh_key.name}' added.")
        |> redirect(to: ssh_key_path(conn, :index))
      {:error, changeset} ->
        conn
        |> put_flash(:error, "Something went wrong! Please check error(s) below.")
        |> put_status(:bad_request)
        |> render("new.html", changeset: %{changeset|action: :insert})
    end
  end
end
