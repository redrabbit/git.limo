defmodule GitGud.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    system_env(:gitgud, GitGud.Repo)
    system_env(:gitgud, GitGud.SSHServer)

    Supervisor.start_link([
      {GitGud.DB, []},
      {GitGud.SSHServer, []},
    ], strategy: :one_for_one, name: GitGud.Supervisor)
  end

  #
  # Helpers
  #

  defp system_env(otp_app, module) do
    config = Application.fetch_env!(otp_app, module)
    Enum.each(config, fn
      {key, {:system, var}} -> Application.put_env(otp_app, key, System.get_env(var))
      {key, {:system, var, default}} -> Application.put_env(otp_app, key, System.get_env(var) || default)
      {_key, _val} -> :ok
    end)
  end
end
