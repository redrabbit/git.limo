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

  alias GitGud.Auth
  alias GitGud.User
  alias GitGud.RepoQuery
  alias GitGud.RepoStorage

  alias GitGud.Authorization

  plug :basic_authentication
  plug :match
  plug :dispatch

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
         %User{} = user <- Auth.check_credentials(login, passwd) do
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
      case GitAgent.attach(repo) do
        {:ok, repo} ->
          refs = WireProtocol.reference_discovery(repo, exec)
          info = WireProtocol.encode(["# service=#{exec}", :flush] ++ refs)
          conn
          |> put_resp_content_type("application/x-#{exec}-advertisement")
          |> send_resp(:ok, info)
        {:error, _reason} ->
          conn
          |> send_resp(:not_found, "Not found")
          |> halt()
      end
    end
  end

  defp git_head_ref(conn, repo) do
    if authorized?(conn, repo, :read) do
      with {:ok, repo} <- GitAgent.attach(repo),
           {:ok, head} <- GitAgent.head(repo) do
        send_resp(conn, :ok, "ref: #{head.prefix <> head.name}")
      else
        {:error, reason} ->
          conn
          |> send_resp(:internal_server_error, reason)
          |> halt()
      end
    end
  end

  defp git_pack(conn, repo, exec) do
    if authorized?(conn, repo, exec) do
      with {:ok, repo} <- GitAgent.attach(repo),
           conn <- put_resp_content_type(conn, "application/x-#{exec}-result"),
           conn <- send_chunked(conn, :ok),
           service <- WireProtocol.new(repo.__agent__, exec, callback: {RepoStorage, [conn.assigns.current_user, repo]}),
           service <- WireProtocol.skip(service),
           {:ok, conn} <- git_stream_pack(conn, service) do
        halt(conn)
      else
        {:error, reason} ->
          conn
          |> send_resp(:internal_server_error, reason)
          |> halt()
      end
    end
  end

  defp git_stream_pack(conn, service) do
    case read_body(conn) do
      {:ok, body, conn} ->
        {service, data} = WireProtocol.next(service, body)
        case chunk(conn, data) do
          {:ok, conn} ->
            if WireProtocol.done?(service) do
              {_service, data} = WireProtocol.next(service)
              chunk(conn, data)
            else
              git_stream_pack(conn, service)
            end
          {:error, reason} ->
            {:error, reason}
        end
      {:more, body, conn} ->
        {service, data} = WireProtocol.next(service, body)
        case chunk(conn, data) do
          {:ok, conn} ->
            git_stream_pack(conn, service)
          {:error, reason} ->
            {:error, reason}
        end
      {:error, reason} ->
        {:error, reason}
    end
  end
end
