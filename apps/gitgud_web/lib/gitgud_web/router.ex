defmodule GitGud.Web.Router do
  @moduledoc false
  use GitGud.Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :authenticate_session
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :graphql do
    plug :fetch_session
    plug :authenticate
  end

  if Mix.env == :dev do
    forward "/sent_emails", Bamboo.SentEmailViewerPlug
  end

  scope "/graphql", GitGud.Web do
    pipe_through :graphql
    forward "/", GraphQLPlug
  end

  scope "/:user_login/:repo_name", GitGud do
    get "/info/refs", SmartHTTPBackend, :discover
    post "/git-receive-pack", SmartHTTPBackend, :receive_pack
    post "/git-upload-pack", SmartHTTPBackend, :upload_pack
  end

  scope "/", GitGud.Web do
    pipe_through :browser

    get "/", LandingPageController, :index

    get "/new", RepoController, :new
    post "/", RepoController, :create

    get "/login", SessionController, :new
    post "/login", SessionController, :create

    get "/logout", SessionController, :delete

    get "/auth/:provider", OAuth2Controller, :authorize, as: :oauth2
    get "/auth/:provider/callback", OAuth2Controller, :callback, as: :oauth2

    get "/register", UserController, :new
    post "/register", UserController, :create

    get "/password/reset", UserController, :reset_password
    post "/password/reset", UserController, :send_password_reset
    get "/password/reset/:token", UserController, :verify_password_reset

    get "/settings/profile", UserController, :edit_profile
    put "/settings/profile", UserController, :update_profile

    get "/settings/password", UserController, :edit_password
    put "/settings/password", UserController, :update_password

    get "/settings/emails", EmailController, :index
    post "/settings/emails", EmailController, :create
    put "/settings/emails", EmailController, :update
    delete "/settings/emails", EmailController, :delete

    post "/settings/emails/verify", EmailController, :send_verification
    get "/settings/emails/verify/:token", EmailController, :verify

    get "/settings/ssh", SSHKeyController, :index
    get "/settings/ssh/new", SSHKeyController, :new
    post "/settings/ssh", SSHKeyController, :create
    delete "/settings/ssh", SSHKeyController, :delete

    get "/settings/gpg", GPGKeyController, :index
    get "/settings/gpg/new", GPGKeyController, :new
    post "/settings/gpg", GPGKeyController, :create
    delete "/settings/gpg", GPGKeyController, :delete

    get "/settings/oauth2", OAuth2Controller, :index, as: :oauth2
    delete "/settings/oauth2", OAuth2Controller, :delete, as: :oauth2

    get "/:user_login", UserController, :show
    get "/:user_login/repositories", RepoController, :index

    scope "/:user_login/:repo_name" do
      live_session :repo, root_layout: {GitGud.Web.LayoutView, "repo.html"} do
        live "/", TreeBrowserLive, :show, as: :codebase

        get "/new/:revision/*path", CodebaseController, :new
        get "/edit/:revision/*path", CodebaseController, :edit
        get "/delete/:revision/*path", CodebaseController, :confirm_delete

        get "/branches", CodebaseController, :branches
        get "/tags", CodebaseController, :tags
        live "/commit/:oid", CommitDiffLive, :commit, as: :codebase
        get "/history", CodebaseController, :history
        live "/history/:revision/*path", CommitHistoryLive, :history, as: :codebase
        live "/tree/:revision/*path", TreeBrowserLive, :tree, as: :codebase
        live "/blob/:revision/*path", BlobViewerLive, :blob, as: :codebase

        get "/issues", IssueController, :index
        get "/issues/new", IssueController, :new
        post "/issues", IssueController, :create
        get "/issues/labels", IssueLabelController, :index
        put "/issues/labels", IssueLabelController, :update
        live "/issues/:number", IssueLive, :show, as: :issue

        get "/settings", RepoController, :edit
        put "/settings", RepoController, :update
        delete "/settings", RepoController, :delete

        get "/settings/maintainers", MaintainerController, :index
        post "/settings/maintainers", MaintainerController, :create
        put "/settings/maintainers", MaintainerController, :update
        delete "/settings/maintainers", MaintainerController, :delete

        post "/:revision/*path", CodebaseController, :create
        put "/:revision/*path", CodebaseController, :update
        delete "/:revision/*path", CodebaseController, :delete
      end
    end
  end
end
