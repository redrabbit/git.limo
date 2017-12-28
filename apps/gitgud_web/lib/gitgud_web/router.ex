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

  # api + token authentication
  scope "/api", GitGud.Web do
    pipe_through :api

    # token generation
    post "/token",                      AuthenticationController, :create, as: :user_token

    scope "/users/:user" do
      scope "/repos" do

        # repositories
        resources "/",                  RepositoryController, param: "repo", except: [:new, :edit]

        scope "/:repo" do

          # branches
          get    "/branches",           RepositoryController, :branch_list
          post   "/branches",           RepositoryController, :create_branch
          get    "/branches/:branch",   RepositoryController, :branch
          put    "/branches/:branch",   RepositoryController, :update_branch
          delete "/branches/:branch",   RepositoryController, :delete_branch

          # tags
          get    "/tags",               RepositoryController, :tag_list
          post   "/tags",               RepositoryController, :create_tag
          get    "/tags/:tag",          RepositoryController, :tag
          put    "/tags/:tag",          RepositoryController, :update_tag
          delete "/tags/:tag",          RepositoryController, :delete_tag

          # commits
          get    "/revwalk/:spec",      RepositoryController, :revwalk
          get    "/commits/:spec",      RepositoryController, :commit

          # trees
          get    "/tree/:spec/*path",   RepositoryController, :browse_tree
          get    "/blob/:spec/*path",   RepositoryController, :download_blob
        end
      end
    end
  end

  # git smart-http + basic auth
  scope "/:user/:repo", GitGud.Web do
    get "/info/refs",                   GitBackendController, :info_refs
    get "/HEAD",                        GitBackendController, :head
    post "/git-upload-pack",            GitBackendController, :upload_pack
    post "/git-receive-pack",           GitBackendController, :receive_pack
  end

  scope "/", GitGud.Web do
    pipe_through :browser

    # single page application
    get "/*page",                       PageController, :index
  end
end
