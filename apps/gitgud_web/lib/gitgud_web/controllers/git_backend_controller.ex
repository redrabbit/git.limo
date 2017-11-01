defmodule GitGud.Web.GitBackendController do
  @moduledoc """
  Module responsible for serving the contents of a Git repository over HTTP.
  """

  use GitGud.Web, :controller

  import Base, only: [decode64: 1]
  import String, only: [split: 3]

  alias GitGud.User
  alias GitGud.Repo
  alias GitGud.RepoQuery

  plug :basic_authentication

  def info_refs(conn, %{"user" => username, "repo" => path, "service" => service}) do
    if repo = RepoQuery.user_repository(username, path),
      do: git_info_refs(conn, repo, service) || require_authentication(conn),
    else: send_resp(conn, :not_found, "Page not found")
  end

  def head(conn, %{"user" => username, "repo" => path}) do
    if repo = RepoQuery.user_repository(username, path),
      do: git_head_ref(conn, repo) || require_authentication(conn),
    else: send_resp(conn, :not_found, "Page not found")
  end

  def receive_pack(conn, %{"user" => username, "repo" => path}) do
    if repo = RepoQuery.user_repository(username, path),
      do: git_pack(conn, repo, "git-receive-pack") || require_authentication(conn),
    else: send_resp(conn, :not_found, "Page not found")
  end

  def upload_pack(conn, %{"user" => username, "repo" => path}) do
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
      case System.cmd(service, ["--advertise-refs", Repo.git_dir(repo)]) do
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
      send_resp(conn, :ok, "ref: #{head.target}")
    end
  end

  defp git_pack(conn, repo, service) do
    if has_permission?(conn, repo, service) do
      {:ok, body, conn} = read_body(conn)
      conn
      |> put_resp_content_type("application/x-#{service}-result")
      |> send_resp(:ok, execute_port(service, Repo.git_dir(repo), body))
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
    repo
    |> Repo.git_dir()
    |> Geef.Repository.open!()
    |> Geef.Reference.lookup!("HEAD")
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
