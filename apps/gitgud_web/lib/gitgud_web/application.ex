defmodule GitGud.Web.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      supervisor(GitGud.Web.Endpoint, []),
      supervisor(Absinthe.Subscription, [GitGud.Web.Endpoint]),
      GitGud.Web.CommentThreadPresence
    ]

    opts = [strategy: :one_for_one, name: GitGud.Web.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    GitGud.Web.Endpoint.config_change(changed, removed)
    :ok
  end
end
