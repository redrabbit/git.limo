defmodule GitGud.Web.GitBackendController do
  @moduledoc """
  Module responsible for serving the contents of a Git repository over HTTP.

  The controller handles following Git commands:

  * `git-receive-pack` - corresponding server-side command to `git push`.
  * `git-upload-pack` - corresponding server-side command to `git fetch`.
  * `git-upload-archive` - corresponding server-side command to `git archive`.

  ## Authentication

  A registered `GitGud.User` can authenticate over HTTP via *Basic Authentication*.
  This is only, required for commands requiring specific permissions (such as pushing commits and cloning private repos).

  To clone a repository, run following command:

      git clone 'http://localhost:4000/USER/REPO'

  ## Authorization

  In order to read and/or write to a repository, a user needs to have the required permissions.

  See `GitGud.Repo.can_read?/2` and `GitGud.Repo.can_write?/2` for more details.
  """

  use GitGud.Web, :controller

  import Base, only: [decode64: 1]
  import String, only: [split: 3]

  alias GitRekt.Git

  alias GitGud.User
  alias GitGud.Repo
  alias GitGud.RepoQuery

  plug :basic_authentication

  @doc """
  Returns all branche and tag references for a repository.
  """
  @spec info_refs(Plug.Conn.t, map) :: Plug.Conn.t
  def info_refs(conn, %{"user" => username, "repo" => path, "service" => service} = _params) do
    if repo = RepoQuery.user_repository(username, path),
      do: git_info_refs(conn, repo, service) || require_authentication(conn),
    else: send_resp(conn, :not_found, "Page not found")
  end

  @doc """
  Returns `HEAD` for a repository.
  """
  @spec head(Plug.Conn.t, map) :: Plug.Conn.t
  def head(conn, %{"user" => username, "repo" => path} = _params) do
    if repo = RepoQuery.user_repository(username, path),
      do: git_head_ref(conn, repo) || require_authentication(conn),
    else: send_resp(conn, :not_found, "Page not found")
  end

  @doc """
  Returns results for a `receive-pack` remote call.
  """
  @spec receive_pack(Plug.Conn.t, map) :: Plug.Conn.t
  def receive_pack(conn, %{"user" => username, "repo" => path} = _params) do
    if repo = RepoQuery.user_repository(username, path),
      do: git_pack(conn, repo, "git-receive-pack") || require_authentication(conn),
    else: send_resp(conn, :not_found, "Page not found")
  end

  @doc """
  Returns results for a `upload-pack` remote call.
  """
  @spec upload_pack(Plug.Conn.t, map) :: Plug.Conn.t
  def upload_pack(conn, %{"user" => username, "repo" => path} = _params) do
    if repo = RepoQuery.user_repository(username, path),
      do: git_pack(conn, repo, "git-upload-pack") || require_authentication(conn),
    else: send_resp(conn, :not_found, "Page not found")
  end

  #
  # Helpers
  #

  defp basic_authentication(conn, _opts) do
    with ["Basic " <> auth] <- get_req_header(conn, "authorization"),
         {:ok, credentials} <- decode64(auth),
         [username, passwd] <- split(credentials, ":", parts: 2),
         %User{} = user <- User.check_credentials(username, passwd) do
      assign(conn, :user, user)
    else
      _ -> conn
    end
  end

  defp require_authentication(conn) do
    conn
    |> put_resp_header("www-authenticate", "Basic realm=\"GitGud\"")
    |> send_resp(:unauthorized, "Unauthorized")
  end

  defp has_permission?(conn, repo, "git-upload-pack"), do: has_permission?(conn, repo, :read)
  defp has_permission?(conn, repo, "git-receive-pack"), do: has_permission?(conn, repo, :write)
  defp has_permission?(conn, repo, :read), do: Repo.can_read?(conn.assigns[:user], repo)
  defp has_permission?(conn, repo, :write), do: Repo.can_write?(conn.assigns[:user], repo)

  defp git_info_refs(conn, repo, service) do
    if has_permission?(conn, repo, service) do
      case System.cmd(service, ["--advertise-refs", Repo.workdir(repo)]) do
        {resp, 0} ->
          conn
          |> put_resp_content_type("application/x-#{service}-advertisement")
          |> send_resp(:ok, prefix_resp("# service=#{service}\n") <> resp)
      end
    end
  end

  defp git_head_ref(conn, repo) do
    if has_permission?(conn, repo, :read) do
      head = head_reference(repo)
      send_resp(conn, :ok, "ref: #{head}")
    end
  end

  defp git_pack(conn, repo, service) do
    if has_permission?(conn, repo, service) do
      {:ok, body, conn} = read_body(conn)
      conn
      |> put_resp_content_type("application/x-#{service}-result")
      |> send_resp(:ok, execute_port(service, Repo.workdir(repo), body))
    end
  end

  defp execute_port(service, repo_path, request) do
    port = Port.open({:spawn, "#{service} --stateless-rpc #{repo_path}"}, [:binary, :exit_status])
    if Port.command(port, request), do: capture_port_output(port)
  end

  defp capture_port_output(port, buffer \\ "") do
    receive do
      {^port, {:data, data}} ->
        capture_port_output(port, buffer <> data)
      {^port, {:exit_status, 0}} ->
        buffer
    end
  end

  defp head_reference(repo) do
    with {:ok, handle} <- Git.repository_open(Repo.workdir(repo)),
         {:ok, target, _oid} <- Git.reference_resolve(handle, "HEAD") do
      target
    else
      {:error, _reason} ->
        nil
    end
  end

  defp flush(), do: "0000"

  defp prefix_resp(resp) do
    resp
    |> byte_size()
    |> Kernel.+(4)
    |> Integer.to_string(16)
    |> String.downcase()
    |> String.pad_leading(4, "0")
    |> Kernel.<>(resp)
    |> Kernel.<>(flush())
  end
end
