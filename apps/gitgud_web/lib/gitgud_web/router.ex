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

  scope "/graphiql" do
    pipe_through :graphql
    forward "/", Absinthe.Plug.GraphiQL,
      socket: GitGud.Web.UserSocket,
      schema: GitGud.GraphQL.Schema
  end

  scope "/", GitGud.Web do
    pipe_through :browser

    get "/login", AuthenticationController, :new
    post "/login", AuthenticationController, :create
    get "/logout", AuthenticationController, :delete

    get "/register", RegistrationController, :new
    post "/users", RegistrationController, :create

    get "/new", RepositoryController, :new
    post "/repositories", RepositoryController, :create

    scope "/:username/:repo_name" do
      get "/", RepositoryController, :show
      get "/branches", RepositoryController, :branches
      get "/tags", RepositoryController, :tags
      get "/commits/:spec", RepositoryController, :commits
      get "/commits", RepositoryController, :commits
      get "/commit/:oid", RepositoryController, :commit
      get "/tree/:spec/*path", RepositoryController, :tree
      get "/blob/:spec/*path", RepositoryController, :blob
    end

    get "/:username", UserProfileController, :show
  end

  scope "/:username/:repo_name" do
    forward "/", GitGud.SmartHTTPBackend
  end
end
