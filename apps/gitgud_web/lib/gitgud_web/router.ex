defmodule GitGud.Web.Router do
  @moduledoc false
  use GitGud.Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :authenticate_session
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :graphql do
    plug :fetch_session
    plug :authenticate
  end

  scope "/graphql" do
    pipe_through :graphql
    forward "/", Absinthe.Plug.GraphiQL,
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

    get "/settings/profile", UserController, :edit_profile
    put "/settings/profile", UserController, :update_profile

    get "/settings/password", UserController, :edit_password
    put "/settings/password", UserController, :update_password

    get "/settings/emails", EmailController, :edit
    post "/settings/emails", EmailController, :create
    put "/settings/emails", EmailController, :update
    delete "/settings/emails", EmailController, :delete
    post "/settings/emails/verify", EmailController, :resend
    get "/settings/emails/verify/:token", EmailController, :verify

    get "/settings/ssh", SSHKeyController, :index
    get "/settings/ssh/new", SSHKeyController, :new
    post "/settings/ssh", SSHKeyController, :create
    delete "/settings/ssh", SSHKeyController, :delete

    get "/new", RepoController, :new
    post "/new", RepoController, :create

    scope "/:user_name/:repo_name" do
      get "/", CodebaseController, :show
      get "/branches", CodebaseController, :branches
      get "/tags", CodebaseController, :tags
      get "/commit/:oid", CodebaseController, :commit
      get "/history", CodebaseController, :history
      get "/history/:revision/*path", CodebaseController, :history
      get "/tree/:revision/*path", CodebaseController, :tree
      get "/blob/:revision/*path", CodebaseController, :blob

      get "/settings", RepoController, :edit
      put "/settings", RepoController, :update
      delete "/settings", RepoController, :delete

      get "/settings/maintainers", MaintainerController, :edit
      post "/settings/maintainers", MaintainerController, :create
      put "/settings/maintainers", MaintainerController, :update
      delete "/settings/maintainers", MaintainerController, :delete
    end

    get "/:user_name", UserController, :show
  end

  scope "/:user_name/:repo_name" do
    forward "/", GitGud.SmartHTTPBackend
  end
end
