import Config

if config_env() == :prod do
  app_name =
    System.get_env("FLY_APP_NAME") ||
    raise "environment variable FLY_APP_NAME is missing."

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
    raise """
    environment variable SECRET_KEY_BASE is missing.
    You can generate one by calling: mix phx.gen.secret
    """

  database_url =
    System.get_env("DATABASE_URL") ||
    raise """
    environment variable DATABASE_URL is missing.
    For example: ecto://USER:PASS@HOST/DATABASE
    """

  git_root =
    System.get_env("GIT_ROOT") ||
    raise "environment variable GIT_ROOT is missing."

  ssh_host_key_dir =
    System.get_env("SSH_HOST_KEY_DIR") ||
    raise "environment variable SSH_HOST_KEY_DIR is missing."

  config :gitgud, GitGud.DB,
    url: database_url,
    socket_options: [:inet6],
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

  config :gitgud, GitGud.RepoStorage, git_root: git_root

  config :gitgud, GitGud.SSHServer,
    port: String.to_integer(System.get_env("SSH_PORT") || "1022"),
    host_key_dir: ssh_host_key_dir

  config :gitgud_web, GitGud.Web.Endpoint,
    server: true,
    url: [scheme: "https", host: "git.limo", port: 443],
    http: [
      port: String.to_integer(System.get_env("PORT") || "4000"),
      transport_options: [socket_opts: [:inet6]]
    ],
    check_origin: [
      "//git.limo",
      "//#{app_name}.fly.dev"
    ],
    secret_key_base: secret_key_base

  config :gitgud_web, GitGud.Mailer,
    adapter: Bamboo.MailgunAdapter,
    api_key: System.get_env("MAILGUN_API_KEY"),
    domain: "mail.git.limo"

  config :gitgud_web, GitGud.OAuth2.GitHub,
    client_id: System.get_env("OAUTH2_GITHUB_CLIENT_ID"),
    client_secret: System.get_env("OAUTH2_GITHUB_CLIENT_SECRET")

  config :gitgud_web, GitGud.OAuth2.GitLab,
    client_id: System.get_env("OAUTH2_GITLAB_CLIENT_ID"),
    client_secret: System.get_env("OAUTH2_GITLAB_CLIENT_SECRET")

  config :libcluster,
    debug: true,
    topologies: [
      fly6pn: [
        strategy: Cluster.Strategy.DNSPoll,
        config: [
          polling_interval: 5_000,
          query: "#{app_name}.internal",
          node_basename: app_name
        ]
      ]
    ]
end
