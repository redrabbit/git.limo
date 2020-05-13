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

  alias GitRekt.GitAgent
  alias GitRekt.WireProtocol

  alias GitGud.Account
  alias GitGud.User
  alias GitGud.RepoQuery
  alias GitGud.RepoStorage

  alias GitGud.Authorization

  plug :basic_authentication
  plug :match
  plug :dispatch

  @max_request_size 10_485_760

  get "/info/refs" do
    if repo = RepoQuery.user_repo(conn.params["user_login"], conn.params["repo_name"]),
      do: git_info_refs(conn, repo, conn.params["service"]) || require_authentication(conn),
    else: send_resp(conn, :not_found, "Not found")
  end

  get "/HEAD" do
    if repo = RepoQuery.user_repo(conn.params["user_login"], conn.params["repo_name"]),
      do: git_head_ref(conn, repo) || require_authentication(conn),
    else: send_resp(conn, :not_found, "Not found")
  end

  post "/git-receive-pack" do
    if repo = RepoQuery.user_repo(conn.params["user_login"], conn.params["repo_name"]),
      do: git_pack(conn, repo, "git-receive-pack") || require_authentication(conn),
    else: send_resp(conn, :not_found, "Not found")
  end

  post "/git-upload-pack" do
    if repo = RepoQuery.user_repo(conn.params["user_login"], conn.params["repo_name"]),
      do: git_pack(conn, repo, "git-upload-pack") || require_authentication(conn),
    else: send_resp(conn, :not_found, "Not found")
  end

  match _ do
    send_resp(conn, :not_found, "Not Found")
  end

  #
  # Helpers
  #

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

  defp git_info_refs(conn, repo, exec) do
    if authorized?(conn, repo, exec) do
      refs = WireProtocol.reference_discovery(repo, exec)
      info = WireProtocol.encode(["# service=#{exec}", :flush] ++ refs)
      conn
      |> put_resp_content_type("application/x-#{exec}-advertisement")
      |> send_resp(:ok, info)
    end
  end

  defp git_head_ref(conn, repo) do
    if authorized?(conn, repo, :read) do
      case GitAgent.head(repo) do
        {:ok, head} ->
          send_resp(conn, :ok, "ref: #{head.prefix <> head.name}")
        {:error, reason} ->
          conn
          |> send_resp(:internal_server_error, reason)
          |> halt()
      end
    end
  end

  defp git_pack(conn, repo, exec) do
    if authorized?(conn, repo, exec) do
      conn = put_resp_content_type(conn, "application/x-#{exec}-result")
      conn = send_chunked(conn, :ok)
      service = WireProtocol.new(repo, exec, callback: {RepoStorage, [repo, conn.assigns.current_user]})
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

  defp git_stream_pack(conn, service, request_size \\ 0)
  defp git_stream_pack(conn, service, request_size) when request_size <= @max_request_size do
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
  end

  defp git_stream_pack(conn, _service, _request_size) do
#   error_status = :request_entity_too_large
#   error_code = Plug.Conn.Status.code(error_status)
#   error_body = Plug.Conn.Status.reason_phrase(error_code)
    {:ok, conn} = chunk(conn, WireProtocol.encode([:flush]))
    {:ok, halt(conn)}
  end
end
