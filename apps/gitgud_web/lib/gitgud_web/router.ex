defmodule GitGud.Web.Router do
  @moduledoc false
  use GitGud.Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug AuthenticationPlug
  end

  scope "/api", GitGud.Web do
    pipe_through :api
    post "/token",                  AuthenticationController, :create, as: :user_token
    scope "/users/:user" do
      scope "/repos" do
        resources "/",              RepositoryController, param: "repo", except: [:new, :edit]
        scope "/:repo" do
          get "/branches",          RepositoryController, :branch_list
          get "/branches/:branch",  RepositoryController, :branch
          get "/tags",              RepositoryController, :tag_list
          get "/tags/:tag",         RepositoryController, :tag
          get "/commits/:spec",     RepositoryController, :revwalk
          get "/tree/:spec/*path",  RepositoryController, :browse_tree
        end
      end
    end
  end

  scope "/:user/:repo", GitGud.Web do
    get "/info/refs",              GitBackendController, :info_refs
    get "/HEAD",                   GitBackendController, :head
    post "/git-upload-pack",       GitBackendController, :upload_pack
    post "/git-receive-pack",      GitBackendController, :receive_pack
  end

  scope "/", GitGud.Web do
    pipe_through :browser
    get "/*page",                   PageController, :index
  end
end
