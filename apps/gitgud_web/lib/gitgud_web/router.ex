defmodule GitGud.Web.Router do
  @moduledoc false
  use GitGud.Web, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", GitGud.Web do
    pipe_through :api
  end
end
