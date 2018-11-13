defmodule GitGud do
  @moduledoc false

  def system_env(otp_app, modules) when is_list(modules) do
    Enum.each(modules, &system_env(otp_app, &1))
  end

  def system_env(otp_app, module) do
    config = Application.fetch_env!(otp_app, module)
    Enum.each(config, fn
      {key, {:system, var}} ->
        Application.put_env(otp_app, key, System.get_env(var))
      {key, val} ->
        :ok
    end)
  end
end
