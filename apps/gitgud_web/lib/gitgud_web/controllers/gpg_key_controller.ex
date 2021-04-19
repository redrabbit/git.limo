defmodule GitGud.Web.GPGKeyController do
  @moduledoc """
  Module responsible for CRUD actions on `GitGud.GPGKey`.
  """

  use GitGud.Web, :controller

  alias GitGud.DB
  alias GitGud.GPGKey

  import GitGud.Web.GPGKeyView, only: [format_key_id: 1]

  plug :ensure_authenticated
  plug :put_layout, :user_settings

  action_fallback GitGud.Web.FallbackController

  @doc """
  Renders GPG keys.
  """
  @spec index(Plug.Conn.t, map) :: Plug.Conn.t
  def index(conn, _params) do
    user = DB.preload(current_user(conn), [:gpg_keys, :emails])
    render(conn, "index.html", user: user)
  end

  @doc """
  Renders a creation form for GPG keys.
  """
  @spec new(Plug.Conn.t, map) :: Plug.Conn.t
  def new(conn, _params) do
    changeset = GPGKey.changeset(%GPGKey{})
    render(conn, "new.html", changeset: changeset)
  end

  @doc """
  Creates a new GPG key.
  """
  @spec create(Plug.Conn.t, map) :: Plug.Conn.t
  def create(conn, %{"gpg_key" => gpg_key_params} = _params) do
    user = current_user(conn)
    case GPGKey.create(user, gpg_key_params) do
      {:ok, gpg_key} ->
        conn
        |> put_flash(:info, "GPG key 0x#{format_key_id(gpg_key.key_id)} added.")
        |> redirect(to: Routes.gpg_key_path(conn, :index))
      {:error, changeset} ->
        conn
        |> put_flash(:error, "Something went wrong! Please check error(s) below.")
        |> put_status(:bad_request)
        |> render("new.html", changeset: %{changeset|action: :insert})
    end
  end

  @doc """
  Deletes a GPG key.
  """
  @spec delete(Plug.Conn.t, map) :: Plug.Conn.t
  def delete(conn, %{"gpg_key" => gpg_key_params} = _params) do
    user = DB.preload(current_user(conn), :gpg_keys)
    gpg_key_id = String.to_integer(gpg_key_params["id"])
    if gpg_key = Enum.find(user.gpg_keys, &(&1.id == gpg_key_id)) do
      gpg_key = GPGKey.delete!(gpg_key)
      conn
      |> put_flash(:info, "GPG key 0x#{format_key_id(gpg_key.key_id)} deleted.")
      |> redirect(to: Routes.gpg_key_path(conn, :index))
    else
      {:error, :bad_request}
    end
  end
end
