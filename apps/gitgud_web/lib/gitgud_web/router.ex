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
    post "/token",                          AuthenticationController, :create, as: :user_token

    scope "/users/:username" do
      scope "/repos" do

        # repositories
        resources "/",                      RepositoryController, param: "repo_path", except: [:new, :edit]

        scope "/:repo_path" do

          # branches
          get    "/branches",               RepositoryController, :branch_list
          post   "/branches",               RepositoryController, :create_branch
          get    "/branches/:branch_name",  RepositoryController, :branch
          put    "/branches/:branch_name",  RepositoryController, :update_branch
          delete "/branches/:branch_name",  RepositoryController, :delete_branch

          # tags
          get    "/tags",                   RepositoryController, :tag_list
          post   "/tags",                   RepositoryController, :create_tag
          get    "/tags/:tag_name",         RepositoryController, :tag
          put    "/tags/:tag_name",         RepositoryController, :update_tag
          delete "/tags/:tag_name",         RepositoryController, :delete_tag

          # commits
          get    "/revwalk/:spec",          RepositoryController, :revwalk
          get    "/commits/:spec",          RepositoryController, :commit

          # trees
          get    "/tree/:spec/*tree_path",  RepositoryController, :browse_tree
          get    "/blob/:spec/*blob_path",  RepositoryController, :download_blob
        end
      end
    end
  end

  # git smart-http + basic auth
  scope "/:user/:repo", GitGud.Web do
    get "/info/refs",                       GitBackendController, :info_refs
    get "/HEAD",                            GitBackendController, :head
    post "/git-upload-pack",                GitBackendController, :upload_pack
    post "/git-receive-pack",               GitBackendController, :receive_pack
  end

  scope "/", GitGud.Web do
    pipe_through :browser

    # single page application
    get "/*page",                           PageController, :index
  end
end
