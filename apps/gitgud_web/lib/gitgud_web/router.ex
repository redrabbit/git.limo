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

    get "/register", UserController, :new
    post "/users", UserController, :create

    get "/settings/profile", UserController, :edit_profile
    put "/settings/profile", UserController, :update_profile
    get "/settings/password", UserController, :edit_password
    put "/settings/password", UserController, :update_password

    get "/settings/emails", EmailController, :index
    post "/settings/emails", EmailController, :create
    delete "/settings/emails", EmailController, :delete
    post "/settings/emails/verify", EmailController, :resend
    get "/settings/emails/verify/:token", EmailController, :verify

    get "/settings/ssh", SSHKeyController, :index
    get "/settings/ssh/new", SSHKeyController, :new
    post "/settings/ssh", SSHKeyController, :create
    delete "/settings/ssh", SSHKeyController, :delete

    get "/new", RepoController, :new
    post "/repositories", RepoController, :create

    scope "/:username/:repo_name" do
      get "/", CodebaseController, :show
      get "/branches", CodebaseController, :branches
      get "/tags", CodebaseController, :tags
      get "/commit/:oid", CodebaseController, :commit
      get "/commits", CodebaseController, :history
      get "/commits/:revision/*path", CodebaseController, :history
      get "/tree/:revision/*path", CodebaseController, :tree
      get "/blob/:revision/*path", CodebaseController, :blob
      get "/settings", RepoController, :edit
      put "/settings", RepoController, :update
    end

    get "/:username", UserController, :show
  end

  scope "/:username/:repo_name" do
    forward "/", GitGud.SmartHTTPBackend
  end
end
