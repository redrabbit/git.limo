defmodule GitGud.Umbrella.Mixfile do
  use Mix.Project

  @version "0.2.4"

  def project do
    [
      apps_path: "apps",
      version: @version,
      name: "Git Gud",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      docs: docs(),
      releases: [
        gitgud: [
          include_executables_for: [:unix],
          applications: [gitgud_web: :permanent, runtime_tools: :permanent]
        ]
      ]
    ]
  end

  #
  # Helpers
  #

  defp deps do
    [{:benchee, "~> 1.0", only: :dev}, {:ex_doc, "~> 0.20", only: :dev}]
  end

  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run apps/gitgud/priv/db/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end

  defp docs do
    [
      main: "getting-started",
      source_ref: "v#{@version}",
      canonical: "https://git.limo",
      source_url: "https://github.com/almightycouch/gitgud",
      extras: [
        "guides/Getting Started.md"
      ],
      groups_for_modules: [
        Database: [
          GitGud.DB,
          GitGud.DBQueryable
        ],
        Authorization: [
          GitGud.Authorization,
          GitGud.AuthorizationPolicies
        ],
        "Schemas & Queries": [
          GitGud.Auth,
          GitGud.OAuth2.Provider,
          GitGud.Comment,
          GitGud.CommentQuery,
          GitGud.Email,
          GitGud.Commit,
          GitGud.CommitLineReview,
          GitGud.CommitReview,
          GitGud.CommitQuery,
          GitGud.GPGKey,
          GitGud.Maintainer,
          GitGud.Repo,
          GitGud.RepoQuery,
          GitGud.RepoStorage,
          GitGud.ReviewQuery,
          GitGud.SSHKey,
          GitGud.User,
          GitGud.UserQuery
        ],
        Deployment: [
          GitGud.ReleaseTasks
        ],
        "Git Transfer Protocols": [
          GitGud.SSHServer,
          GitGud.SmartHTTPBackend
        ],
        "OAuth2.0": [
          GitGud.OAuth2.GitHub,
          GitGud.OAuth2.GitLab
        ],
        GraphQL: [
          GitGud.GraphQL.Resolvers,
          GitGud.GraphQL.Schema,
          GitGud.GraphQL.Types
        ],
        "Email Delivery": [
          GitGud.Mailer
        ],
        Web: [
          GitGud.Web,
          GitGud.Web.AuthenticationPlug,
          GitGud.Web.CodebaseController,
          GitGud.Web.DateTimeFormatter,
          GitGud.Web.EmailController,
          GitGud.Web.Endpoint,
          GitGud.Web.ErrorHelpers,
          GitGud.Web.ErrorView,
          GitGud.Web.FallbackController,
          GitGud.Web.FormHelpers,
          GitGud.Web.Gettext,
          GitGud.Web.GPGKeyController,
          GitGud.Web.Gravatar,
          GitGud.Web.LandingPageController,
          GitGud.Web.MaintainerController,
          GitGud.Web.Markdown,
          GitGud.Web.NavigationHelpers,
          GitGud.Web.OAuth2Controller,
          GitGud.Web.PaginationHelpers,
          GitGud.Web.ReactComponents,
          GitGud.Web.RepoController,
          GitGud.Web.Router.Helpers,
          GitGud.Web.SSHKeyController,
          GitGud.Web.SessionController,
          GitGud.Web.UserController,
          GitGud.Web.UserSocket
        ],
        "Git low-level APIs": [
          GitRekt.GitAgent,
          GitRekt.Git,
          GitRekt.Packfile,
          GitRekt.WireProtocol,
          GitRekt.WireProtocol.ReceivePack,
          GitRekt.WireProtocol.UploadPack
        ]
      ]
    ]
  end
end
