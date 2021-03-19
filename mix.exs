defmodule GitGud.Umbrella.Mixfile do
  use Mix.Project

  @version "0.3.5"

  def project do
    [
      apps_path: "apps",
      version: @version,
      name: "Git Gud",
      start_permanent: Mix.env == :prod,
      aliases: aliases(),
      deps: deps(),
      docs: docs(),
      releases: [
        gitgud: [
          applications: [gitgud_web: :permanent, runtime_tools: :permanent],
          include_executables_for: [:unix],
          steps: [:assemble, :tar]
        ]
      ]
    ]
  end

  #
  # Helpers
  #

  defp deps do
    [
      {:benchee, "~> 1.0", only: :dev},
      {:ex_doc, "~> 0.24", only: :dev}
    ]
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
        "guides/Getting Started.md",
      ],
      groups_for_modules: [
        "Database": [
          GitGud.DB,
          GitGud.DBQueryable
        ],
        "Authorization": [
          GitGud.Authorization,
          GitGud.AuthorizationPolicies
        ],
        "Schemas & Queries": [
          GitGud,
          GitGud.Account,
          GitGud.Comment,
          GitGud.CommentQuery,
          GitGud.CommentRevision,
          GitGud.Email,
          GitGud.Commit,
          GitGud.CommitLineReview,
          GitGud.CommitQuery,
          GitGud.GPGKey,
          GitGud.GPGKeyQuery,
          GitGud.Issue,
          GitGud.IssueLabel,
          GitGud.IssueQuery,
          GitGud.Maintainer,
          GitGud.Repo,
          GitGud.RepoStats,
          GitGud.RepoQuery,
          GitGud.ReviewQuery,
          GitGud.SSHKey,
          GitGud.User,
          GitGud.UserQuery
        ],
        "Repository Management": [
          GitGud.RepoPool,
          GitGud.RepoPoolMonitor,
          GitGud.RepoStorage,
          GitGud.RepoSupervisor,
        ],
        "Git Transfer Protocols": [
          GitGud.SSHServer,
          GitGud.SmartHTTPBackend
        ],
        "OAuth2.0": [
          GitGud.OAuth2.GitHub,
          GitGud.OAuth2.GitLab,
          GitGud.OAuth2.Provider,
        ],
        "GraphQL": [
          GitGud.GraphQL.Resolvers,
          GitGud.GraphQL.Schema,
          GitGud.GraphQL.Schema.Compiled,
          GitGud.GraphQL.Types
        ],
        "Email Delivery": [
          GitGud.Mailer
        ],
        "Web": [
          GitGud.Web,
          GitGud.Web.AuthenticationPlug,
          GitGud.Web.CodebaseController,
          GitGud.Web.DateTimeFormatter,
          GitGud.Web.EmailController,
          GitGud.Web.Emoji,
          GitGud.Web.Endpoint,
          GitGud.Web.ErrorHelpers,
          GitGud.Web.ErrorView,
          GitGud.Web.FallbackController,
          GitGud.Web.FormHelpers,
          GitGud.Web.Gettext,
          GitGud.Web.GPGKeyController,
          GitGud.Web.Gravatar,
          GitGud.Web.IssueController,
          GitGud.Web.IssueLabelController,
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
          GitGud.Web.TrailingFormatPlug,
          GitGud.Web.UserController,
          GitGud.Web.UserSocket,
          GitGud.Web.XForwardedForPlug
        ],
        "Git low-level APIs": [
          GitRekt,
          GitRekt.Cache,
          GitRekt.Git,
          GitRekt.GitAgent,
          GitRekt.GitRepo,
          GitRekt.GitOdb,
          GitRekt.GitCommit,
          GitRekt.GitRef,
          GitRekt.GitTag,
          GitRekt.GitBlob,
          GitRekt.GitDiff,
          GitRekt.GitTree,
          GitRekt.GitTreeEntry,
          GitRekt.GitIndex,
          GitRekt.GitIndexEntry,
          GitRekt.Packfile,
          GitRekt.WireProtocol,
          GitRekt.WireProtocol.ReceivePack,
          GitRekt.WireProtocol.UploadPack
        ],
      ]
    ]
  end
end
