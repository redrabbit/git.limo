defmodule GitGud.SmartHTTPBackend do
  @moduledoc """
  `Plug` providing support for Git server commands over HTTP.

  This plug handles following Git commands:

  * `git-receive-pack` - corresponding server-side command to `git push`.
  * `git-upload-pack` - corresponding server-side command to `git fetch`.

  ## Example

  Here is an example of `GitGud.SmartHTTPBackend` used in a `Plug.Router` to handle Git server commands:

  ```elixir
  defmodule SmartHTTPBackendRouter do
    use Plug.Router

    plug :match
    plug :fetch_query_params
    plug :dispatch

    get "/:user_login/:repo_name/info/refs", to: GitGud.SmartHTTPBackend, init_opts: :discovery
    post "/:user_login/:repo_name/git-receive-pack", to: GitGud.SmartHTTPBackend, init_opts: :receive_pack
    post "/:user_login/:repo_name/git-upload-pack", to: GitGud.SmartHTTPBackend, init_opts: :upload_pack
  end
  ```

  Note that `user_login` and `repo_name` path parameters are mandatory.

  To process Git commands over HTTP, simply start a Cowboy server as part of your supervision tree:

  ```elixir
  children = [
    {Plug.Cowboy, scheme: :http, plug: SmartHTTPBackendRouter}
  ]

  Supervisor.start_link(children, strategy: :one_for_one)
  ```

  ## Authentication

  A registered `GitGud.User` can authenticate over HTTP via *Basic Authentication*.
  This is required to execute commands with granted permissions (such as pushing commits and cloning private repos).

  See `GitGud.Authorization` for more details.
  """

  use Plug.Builder

  import Base, only: [decode64: 1]
  import String, only: [split: 3]

  alias GitRekt.GitRepo
  alias GitRekt.WireProtocol

  alias GitGud.Account
  alias GitGud.User
  alias GitGud.RepoQuery
  alias GitGud.RepoStorage

  alias GitGud.Authorization

  plug :basic_authentication

  @doc """
  Returns all references available for the given Git repository.
  """
  @spec discovery(Plug.Conn.t, keyword) :: Plug.Conn.t
  def discovery(conn, _opts) do
    if repo = fetch_user_repo(conn),
      do: git_info_refs(conn, repo, conn.params["service"]) || require_authentication(conn),
    else: require_authentication_or_404(conn)
  end

  @doc """
  Processes `git-receive-pack` requests.
  """
  @spec receive_pack(Plug.Conn.t, keyword) :: Plug.Conn.t
  def receive_pack(conn, _opts) do
    if repo = fetch_user_repo(conn),
      do: git_pack(conn, repo, "git-receive-pack") || require_authentication(conn),
    else: require_authentication_or_404(conn)
  end

  @doc """
  Processes `git-upload-pack` requests.
  """
  @spec upload_pack(Plug.Conn.t, keyword) :: Plug.Conn.t
  def upload_pack(conn, _opts) do
    if repo = fetch_user_repo(conn),
      do: git_pack(conn, repo, "git-upload-pack") || require_authentication(conn),
    else: require_authentication_or_404(conn)
  end

  #
  # Callbacks
  #

  @impl true
  def init(action), do: action

  @impl true
  def call(conn, action) do
    opts = []
    apply(__MODULE__, action, [super(conn, opts), opts])
  end

  #
  # Helpers
  #

  defp fetch_user_repo(conn) do
    user_login = conn.params["user_login"]
    repo_name = conn.params["repo_name"]
    if String.ends_with?(repo_name, ".git") do
      RepoQuery.user_repo(user_login, String.slice(repo_name, 0..-5), viewer: conn.assigns[:current_user])
    end
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

  defp require_authentication_or_404(conn) do
    if is_nil(conn.assigns[:current_user]),
      do: require_authentication(conn),
    else: send_resp(conn, :not_found, "Not found")
  end

  defp git_info_refs(conn, repo, exec) when exec in ["git-upload-pack", "git-receive-pack"] do
    if authorized?(conn, repo, exec) do
      {:ok, agent} = GitRepo.get_agent(repo)
      refs = WireProtocol.reference_discovery(agent, exec)
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
