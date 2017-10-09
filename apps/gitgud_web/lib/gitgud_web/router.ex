defmodule GitGudWeb.Router do
  use GitGudWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", GitGudWeb do
    pipe_through :api
  end
end
