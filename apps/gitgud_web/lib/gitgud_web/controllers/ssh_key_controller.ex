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
  def create(conn, %{"ssh_key" => ssh_key_params} = _params) do
    user = current_user(conn)
    case SSHKey.create(user, ssh_key_params) do
      {:ok, ssh_key} ->
        conn
        |> put_flash(:info, "SSH key '#{ssh_key.name}' added.")
        |> redirect(to: Routes.ssh_key_path(conn, :index))
      {:error, changeset} ->
        conn
        |> put_flash(:error, "Something went wrong! Please check error(s) below.")
        |> put_status(:bad_request)
        |> render("new.html", changeset: %{changeset|action: :insert})
    end
  end

  @doc """
  Deletes a SSH key.
  """
  @spec delete(Plug.Conn.t, map) :: Plug.Conn.t
  def delete(conn, %{"ssh_key" => ssh_key_params} = _params) do
    user = DB.preload(current_user(conn), :ssh_keys)
    ssh_key_id = String.to_integer(ssh_key_params["id"])
    if ssh_key = Enum.find(user.ssh_keys, &(&1.id == ssh_key_id)) do
      ssh_key = SSHKey.delete!(ssh_key)
      conn
      |> put_flash(:info, "SSH key '#{ssh_key.name}' deleted.")
      |> redirect(to: Routes.ssh_key_path(conn, :index))
    else
      {:error, :bad_request}
    end
  end

end
