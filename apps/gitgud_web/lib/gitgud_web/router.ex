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

    get "/login", SessionController, :new
    post "/login", SessionController, :create
    get "/logout", SessionController, :delete

    get "/register", UserController, :new
    post "/users", UserController, :create

    get "/settings", UserController, :edit
    put "/settings", UserController, :update

    get "/settings/ssh", SSHAuthenticationKeyController, :index
    get "/settings/ssh/new", SSHAuthenticationKeyController, :new
    post "/settings/ssh", SSHAuthenticationKeyController, :create

    get "/new", RepositoryController, :new
    post "/repositories", RepositoryController, :create

    scope "/:username/:repo_name" do
      get "/", CodebaseController, :show
      get "/branches", CodebaseController, :branches
      get "/tags", CodebaseController, :tags
      get "/commit/:oid", CodebaseController, :commit
      get "/commits", CodebaseController, :history
      get "/commits/:revision", CodebaseController, :history
      get "/tree/:revision/*path", CodebaseController, :tree
      get "/blob/:revision/*path", CodebaseController, :blob
      get "/settings", RepositoryController, :edit
      put "/settings", RepositoryController, :update
    end

    get "/:username", UserController, :show
  end

  scope "/:username/:repo_name" do
    forward "/", GitGud.SmartHTTPBackend
  end
end
