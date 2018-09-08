defmodule GitGud.Web.Router do
  @moduledoc false
  use GitGud.Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug AuthenticationPlug
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  forward "/graphiql", Absinthe.Plug.GraphiQL, schema: GitGud.GraphQL.Schema

  scope "/", GitGud.Web do
    pipe_through :browser

    get "/login", AuthenticationController, :new
    post "/login", AuthenticationController, :create
    get "/logout", AuthenticationController, :delete

    get "/new", RepositoryController, :new
    post "/repositories", RepositoryController, :create

    scope "/:username/:repo_name" do
      get "/", RepositoryController, :show
      get "/tree", RepositoryController, :tree
      get "/tree/:spec/*path", RepositoryController, :tree
      get "/blob/:spec/*path", RepositoryController, :blob
    end

    get "/:username", UserProfileController, :show
  end

  scope "/:username/:repo_path" do
    forward "/", GitGud.SmartHTTPBackend
  end
end
