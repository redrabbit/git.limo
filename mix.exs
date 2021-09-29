defmodule GitLimo.Umbrella.Mixfile do
  use Mix.Project

  @version "0.3.7"

  def project do
    [
      apps_path: "apps",
      version: @version,
      name: "git.limo",
      start_permanent: Mix.env == :prod,
      aliases: aliases(),
      deps: deps(),
      docs: docs(),
      releases: [
        git_limo: [
          applications: [
            gitgud_web: :permanent,
            runtime_tools: :permanent
          ],
          include_executables_for: [:unix],
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
      {:ex_doc, "~> 0.25", only: :dev}
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
      logo: "apps/gitgud_web/assets/static/images/logo.svg",
      source_ref: "v#{@version}",
      canonical: "https://git.limo",
      source_url: "https://github.com/almightycouch/gitgud",
      extras: [
        "guides/Getting Started.md",
      ],
      groups_for_modules: [
        "Database": [
          GitGud.DB,
          GitGud.DBQueryable,
          GitGud.ReleaseTasks
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
          GitGud.RepoQuery,
          GitGud.ReviewQuery,
          GitGud.SSHKey,
          GitGud.User,
          GitGud.UserQuery
        ],
        "Repository Management": [
          GitGud.RepoMonitor,
          GitGud.RepoPool,
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
          GitGud.Web.AuthenticationLiveHelpers,
          GitGud.Web.BlobHeaderLive,
          GitGud.Web.BranchSelectContainerLive,
          GitGud.Web.BranchSelectLive,
          GitGud.Web.CodebaseController,
          GitGud.Web.CommentFormLive,
          GitGud.Web.CommentLive,
          GitGud.Web.CommitDiffLive,
          GitGud.Web.CommitLineReviewLive,
          GitGud.Web.DateTimeFormatter,
          GitGud.Web.EmailController,
          GitGud.Web.Emoji,
          GitGud.Web.Endpoint,
          GitGud.Web.ErrorHelpers,
          GitGud.Web.ErrorView,
          GitGud.Web.FallbackController,
          GitGud.Web.FormHelpers,
          GitGud.Web.Gettext,
          GitGud.Web.GlobalSearchLive,
          GitGud.Web.GPGKeyController,
          GitGud.Web.Gravatar,
          GitGud.Web.IssueController,
          GitGud.Web.IssueLive,
          GitGud.Web.IssueEventLive,
          GitGud.Web.IssueFormLive,
          GitGud.Web.IssueLabelController,
          GitGud.Web.IssueLabelSelectLive,
          GitGud.Web.LandingPageController,
          GitGud.Web.MaintainerController,
          GitGud.Web.MaintainerSearchFormLive,
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
          GitGud.Web.TreeBrowserLive,
          GitGud.Web.UserController,
          GitGud.Web.UserSocket,
          GitGud.Web.XForwardedForPlug
        ],
        "Git low-level APIs": [
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
          GitRekt.GitWritePack,
          GitRekt.Packfile,
          GitRekt.WireProtocol,
          GitRekt.WireProtocol.ReceivePack,
          GitRekt.WireProtocol.UploadPack
        ],
      ]
    ]
  end
end
