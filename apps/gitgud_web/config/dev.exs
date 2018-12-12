use Mix.Config

# The watchers configuration can be used to run external
# watchers to your application.
config :gitgud_web, GitGud.Web.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [
    node: [
      "node_modules/webpack/bin/webpack.js",
      "--mode",
      "development",
      "--watch-stdin",
      "--progress",
      "--color",
      cd: Path.expand("../assets", __DIR__)
    ],
    node: [
      "node_modules/relay-compiler/bin/relay-compiler",
      "--src", "./js",
      "--schema", "../priv/graphql/schema.json",
      "--watch",
      cd: Path.expand("../assets", __DIR__)
    ]
  ],
  live_reload: [
    patterns: [
      ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$},
      ~r{priv/gettext/.*(po)$},
      ~r{lib/gitgud_web/views/.*(ex)$},
      ~r{lib/gitgud_web/templates/.*(eex)$}
    ]
  ]

# Configure GitHub OAuth2.0 provider
config :gitgud_web, GitGud.OAuth2.GitHub,
  client_id: "503f14433fb7334fdbd0",
  client_secret: "3ba722afd4de11c4f53e248218f3bba3c4e5fba5"

# Configure Mailgun adapter
config :gitgud_web, GitGud.Mailer,
  adapter: Bamboo.MailgunAdapter,
  api_key: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-xxxxxxxx-xxxxxxxx",
  domain: "example.com"

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime
