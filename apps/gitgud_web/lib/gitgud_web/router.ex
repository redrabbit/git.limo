defmodule GitGud.Web.Router do
  @moduledoc false
  use GitGud.Web, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug AuthenticationPlug
  end

  scope "/api", GitGud.Web do
    pipe_through :api

    post "/token",                  AuthenticationController, :create, as: :auth_token

    scope "/users/:user" do
      scope "/repos" do
        resources "/",              RepositoryController, param: "repo", except: [:new, :edit]
        scope "/:repo" do
          get "/tree/:dwim/*path",  RepositoryController, :browse
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
end
