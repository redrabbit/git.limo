import Config

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
      "--color",
      "--watch",
      cd: Path.expand("../assets", __DIR__)
    ],
    node: [
      "node_modules/relay-compiler/bin/relay-compiler",
      "--src",
      "./js",
      "--schema",
      "../priv/graphql/schema.graphql",
      "--quiet",
      "--watch",
      cd: Path.expand("../assets", __DIR__)
    ]
  ],
  live_reload: [
    patterns: [
      ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$},
      ~r{priv/gettext/.*(po)$},
      ~r{lib/gitgud_web/views/.*(ex)$},
      ~r{lib/gitgud_web/templates/.*(eex)$},
      ~r{lib/gitgud_web/live/.*(ex)$}
    ]
  ]

# Configure Bamboo adapter
config :gitgud_web, GitGud.Mailer,
  adapter: Bamboo.LocalAdapter,
  open_email_in_browser_url: "http://localhost:4000/sent_emails"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Disable GraphQL logging
config :absinthe, :log, false
