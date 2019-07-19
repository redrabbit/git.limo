defmodule GitGud.Web.Router do
  @moduledoc false
  use GitGud.Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug Phoenix.LiveView.Flash
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

  scope "/graphql" do
    pipe_through :graphql
    forward "/", Absinthe.Plug.GraphiQL,
      json_codec: Jason,
      socket: GitGud.Web.UserSocket,
      schema: GitGud.GraphQL.Schema
  end

  scope "/", GitGud.Web do
    pipe_through :browser

    get "/", LandingPageController, :index

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

    get "/new", RepoController, :new
    post "/new", RepoController, :create

    scope "/:user_login/:repo_name" do
      get "/", CodebaseController, :show
      get "/branches", CodebaseController, :branches
      get "/tags", CodebaseController, :tags
      get "/commit/:oid", CodebaseController, :commit
      delete "/commit/:oid/comments/:id", CodebaseController, :delete_commit_comment
      get "/history", CodebaseController, :history
      get "/history/:revision/*path", CodebaseController, :history
      get "/tree/:revision/*path", CodebaseController, :tree
      get "/blob/:revision/*path", CodebaseController, :blob

      get "/settings", RepoController, :edit
      put "/settings", RepoController, :update
      delete "/settings", RepoController, :delete

      get "/settings/maintainers", MaintainerController, :index
      post "/settings/maintainers", MaintainerController, :create
      put "/settings/maintainers", MaintainerController, :update
      delete "/settings/maintainers", MaintainerController, :delete
    end

    get "/:user_login", UserController, :show
  end

  scope "/:user_login/:repo_name" do
    forward "/", GitGud.SmartHTTPBackend
  end
end
