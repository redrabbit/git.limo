defmodule GitGud.SmartHTTPBackend do
  @moduledoc """
  `Plug` providing support for Git server commands over HTTP.

  This plug handles following Git commands:

  * `git-receive-pack` - corresponding server-side command to `git push`.
  * `git-upload-pack` - corresponding server-side command to `git fetch`.

  A registered `GitGud.User` can authenticate over HTTP via *Basic Authentication*.
  This is only, required for commands requiring specific permissions (such as pushing commits and cloning private repos).

  See `GitGud.Authorization` for more details.
  """

  use Plug.Router

  import Base, only: [decode64: 1]
  import String, only: [split: 3]

  alias GitRekt.WireProtocol

  alias GitGud.Account
  alias GitGud.User
  alias GitGud.RepoQuery
  alias GitGud.RepoStorage

  alias GitGud.Authorization

  plug :basic_authentication
  plug :match
  plug :dispatch

  get "/info/refs" do
    {user_login, repo_name} = fetch_user_repo!(conn)
    if repo = RepoQuery.user_repo(user_login, repo_name),
      do: git_info_refs(conn, repo, conn.params["service"]) || require_authentication(conn),
    else: send_resp(conn, :not_found, "Not found")
  end

  post "/git-receive-pack" do
    {user_login, repo_name} = fetch_user_repo!(conn)
    if repo = RepoQuery.user_repo(user_login, repo_name),
      do: git_pack(conn, repo, "git-receive-pack") || require_authentication(conn),
    else: send_resp(conn, :not_found, "Not found")
  end

  post "/git-upload-pack" do
    {user_login, repo_name} = fetch_user_repo!(conn)
    if repo = RepoQuery.user_repo(user_login, repo_name),
      do: git_pack(conn, repo, "git-upload-pack") || require_authentication(conn),
    else: send_resp(conn, :not_found, "Not found")
  end

  match _, do: raise_phoenix_no_route_error(conn)

  #
  # Helpers
  #

  defp fetch_user_repo!(conn) do
    user_login = conn.params["user_login"]
    repo_name = conn.params["repo_name"]
    if String.ends_with?(repo_name, ".git"),
      do: {user_login, String.slice(repo_name, 0..-5)},
    else: raise_phoenix_no_route_error(conn)
  end

  defp authorized?(conn, repo, "git-upload-pack"),  do: authorized?(conn, repo, :read)
  defp authorized?(conn, repo, "git-receive-pack"), do: authorized?(conn, repo, :write)
  defp authorized?(conn, repo, action), do: Authorization.authorized?(conn.assigns[:current_user], repo, action)

  defp basic_authentication(conn, _opts) do
    with ["Basic " <> auth] <- get_req_header(conn, "authorization"),
         {:ok, credentials} <- decode64(auth),
         [login, passwd] <- split(credentials, ":", parts: 2),
         %User{} = user <- Account.check_credentials(login, passwd) do
      assign(conn, :current_user, user)
    else
      _ -> conn
    end
  end

  defp require_authentication(conn) do
    conn
    |> put_resp_header("www-authenticate", "Basic realm=\"GitGud\"")
    |> send_resp(:unauthorized, "Unauthorized")
    |> halt()
  end

  defp raise_phoenix_no_route_error(conn) do
    conn = %{conn|path_info: String.split(conn.request_path, "/", trim: true)}
    raise Phoenix.Router.NoRouteError, conn: conn, router: GitGud.Web.Router
  end

  defp git_info_refs(conn, repo, exec) when exec in ["git-upload-pack", "git-receive-pack"] do
    if authorized?(conn, repo, exec) do
      refs = WireProtocol.reference_discovery(repo, exec)
      info = WireProtocol.encode(["# service=#{exec}", :flush] ++ refs)
      conn
      |> put_resp_content_type("application/x-#{exec}-advertisement")
      |> send_resp(:ok, info)
    end
  end

  defp git_info_refs(conn, _repo, _exec), do: send_resp(conn, :forbidden, "Forbidden")

  defp git_pack(conn, repo, exec) do
    if authorized?(conn, repo, exec) do
      conn = put_resp_content_type(conn, "application/x-#{exec}-result")
      conn = send_chunked(conn, :ok)
      service = WireProtocol.new(repo, exec, callback: {RepoStorage, [repo, conn.assigns[:current_user]]})
      service = WireProtocol.skip(service)
      case git_stream_pack(conn, service) do
        {:ok, conn} ->
        halt(conn)
        {:error, _reason} ->
          conn
          |> send_resp(:internal_server_error, "Something went wrong")
          |> halt()
      end
    end
  end

  defp git_stream_pack(conn, service, request_size \\ 0) do
    if request_size <= Application.get_env(:gitgud, :git_max_request_size, :infinity) do
      case read_body(conn) do
        {:ok, body, conn} ->
          {service, data} = WireProtocol.next(service, body)
          case chunk(conn, data) do
            {:ok, conn} ->
              if WireProtocol.done?(service) do
                {_service, data} = WireProtocol.next(service)
                chunk(conn, data)
              else
                git_stream_pack(conn, service, request_size + byte_size(body))
              end
            {:error, reason} ->
              {:error, reason}
          end
        {:more, body, conn} ->
          {service, data} = WireProtocol.next(service, body)
          case chunk(conn, data) do
            {:ok, conn} ->
              git_stream_pack(conn, service, request_size + byte_size(body))
            {:error, reason} ->
              {:error, reason}
          end
        {:error, reason} ->
          {:error, reason}
      end
    else
    # error_status = :request_entity_too_large
    # error_code = Plug.Conn.Status.code(error_status)
    # error_body = Plug.Conn.Status.reason_phrase(error_code)
      {:ok, conn} = chunk(conn, WireProtocol.encode([:flush]))
      {:ok, halt(conn)}
    end
  end
end
