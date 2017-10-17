defmodule GitGud.Web.Router do
  @moduledoc false
  use GitGud.Web, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug AuthenticationPlug
  end

  scope "/api", GitGud.Web do
    pipe_through :api

    scope "/users/:user" do
      resources "/repos", RepositoryController, param: "repo", except: [:new, :edit]
    end
  end
end
