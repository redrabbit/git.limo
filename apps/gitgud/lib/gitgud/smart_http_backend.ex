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

    get "/:user_login/:repo_name/info/refs", to: GitGud.SmartHTTPBackend, init_opts: :discover
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

  alias GitRekt.GitAgent
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
  @spec discover(Plug.Conn.t, keyword) :: Plug.Conn.t
  def discover(conn, _opts) do
    case fetch_user_repo(conn) do
      {:ok, repo} ->
        git_info_refs(conn, repo)
      {:error, status_error} ->
        halt_with_error(conn, status_error)
    end
  end

  @doc """
  Processes `git-receive-pack` requests.
  """
  @spec receive_pack(Plug.Conn.t, keyword) :: Plug.Conn.t
  def receive_pack(conn, _opts) do
    service = "git-receive-pack"
    case fetch_user_repo(conn, service) do
      {:ok, repo} ->
        git_pack(conn, repo, service)
      {:error, status_error} ->
        halt_with_error(conn, status_error)
    end
  end

  @doc """
  Processes `git-upload-pack` requests.
  """
  @spec upload_pack(Plug.Conn.t, keyword) :: Plug.Conn.t
  def upload_pack(conn, _opts) do
    service = "git-upload-pack"
    case fetch_user_repo(conn, service) do
      {:ok, repo} ->
        git_pack(conn, repo, service)
      {:error, status_error} ->
        halt_with_error(conn, status_error)
    end
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

  defp fetch_user_repo(conn, service \\ nil) do
    user_login = conn.path_params["user_login"]
    repo_name = conn.path_params["repo_name"]
    service = service || conn.query_params["service"]
    cond do
      is_nil(user_login) ->
        {:error, :not_found}
      is_nil(repo_name) ->
        {:error, :not_found}
      !String.ends_with?(repo_name, ".git") ->
        {:error, :not_found}
      service not in ["git-receive-pack", "git-upload-pack"] ->
        {:error, :bad_request}
      repo = RepoQuery.user_repo(user_login, String.slice(repo_name, 0..-5), viewer: conn.assigns[:current_user]) ->
        cond do
          authorized?(conn, repo, service) ->
            {:ok, repo}
          is_nil(conn.assigns[:current_user]) ->
            {:error, :unauthorized}
          true ->
            {:error, :forbidden}
        end
      is_nil(conn.assigns[:current_user]) ->
        {:error, :unauthorized}
      true ->
        {:error, :not_found}
    end
  end

  defp authorized?(conn, repo, "git-upload-pack"), do: authorized?(conn, repo, :pull)
  defp authorized?(conn, repo, "git-receive-pack"), do: authorized?(conn, repo, :push)
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

  defp halt_with_error(conn, status) do
    case status do
      :bad_request ->
        conn
        |> send_resp(:bad_request, "Bad Request")
        |> halt()
      :unauthorized ->
        conn
        |> put_resp_header("www-authenticate", "Basic realm=\"GitGud\"")
        |> send_resp(:unauthorized, "Unauthorized")
        |> halt()
      :forbidden ->
        conn
        |> send_resp(:forbidden, "Forbidden")
        |> halt()
      :not_found ->
        conn
        |> send_resp(:not_found, "Not Found")
        |> halt()
    end
  end

  defp git_info_refs(conn, repo) do
    case GitAgent.start_link(RepoStorage.workdir(repo)) do
      {:ok, agent} ->
        exec = conn.query_params["service"]
        refs = WireProtocol.reference_discovery(agent, exec, extra_server_capabilities(exec))
        info = WireProtocol.encode(["# service=#{exec}", :flush] ++ refs)
        conn
        |> put_resp_content_type("application/x-#{exec}-advertisement")
        |> send_resp(:ok, info)
      {:error, _reason} ->
        send_resp(conn, :internal_server_error, "Something went wrong")
    end
  end

  defp git_pack(conn, repo, exec) do
    case GitAgent.start_link(RepoStorage.workdir(repo)) do
      {:ok, agent} ->
        conn = put_resp_content_type(conn, "application/x-#{exec}-result")
        conn = send_chunked(conn, :ok)
        service = WireProtocol.skip(WireProtocol.new(agent, exec, caps: extra_server_capabilities(exec), repo: repo))
        case git_stream_pack(conn, service) do
          {:ok, conn} ->
            halt(conn)
          {:error, _reason} ->
            conn
            |> send_resp(:internal_server_error, "Something went wrong")
            |> halt()
        end
      {:error, _reason} ->
        send_resp(conn, :internal_server_error, "Something went wrong")
    end
  end

  defp git_stream_pack(conn, service, request_size \\ 0) do
    if request_size <= Application.get_env(:gitgud, :git_max_request_size, :infinity) do
      case read_next(conn) do
        {ok_or_more, body, conn} when ok_or_more in [:ok, :more] ->
          case WireProtocol.next(service, body) do
            {:cont, service, output} ->
              case chunk(conn, output) do
                {:ok, conn} ->
                  git_stream_pack(conn, service, request_size + byte_size(body))
                {:error, reason} ->
                  {:error, reason}
              end
            {:halt, _service, output} ->
              chunk(conn, output)
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

  defp read_next(conn) do
    case read_body(conn) do
      {ok_or_more, body, conn} when ok_or_more in [:ok, :more] ->
        {ok_or_more, inflate_body(body, body_encoding(conn.req_headers)), conn}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp inflate_body(<<31, 139, 8, _rest::binary>> = body, :gzip), do: :zlib.gunzip(body)
  defp inflate_body(body, :deflate), do: :zlib.unzip(body)
  defp inflate_body(body, :none), do: body

  defp body_encoding(headers) do
    cond do
      Enum.any?(headers, &(&1 in [{"content-encoding", "gzip"}, {"content-encoding", "x-gzip"}])) ->
        :gzip
      Enum.member?(headers, {"content-encoding", "deflate"}) ->
        :deflate
      true ->
        :none
    end
  end

  defp extra_server_capabilities("git-receive-pack"), do: []
  defp extra_server_capabilities("git-upload-pack"), do: ["no-done"]
end
