defmodule GitGud.Web.AssetPipeline do
  use Mix.Releases.Plugin

  def before_assembly(%Release{} = release, _opts) do
    info "Building assets"
    environment = [{"MIX_ENV", to_string(release.env)}]
         {_out, 0} <- System.cmd("npm", ["run", "deploy"], cd: "apps/gitgud_web/assets"),
         {_out, 0} <- System.cmd("mix", ["phx.digest"], cd: "apps/gitgud_web", env: environment) do
      nil
    else
      {output, error_code} -> {:error, output, error_code}
    end
  end

  def after_assembly(%Release{} = _release, _opts), do: nil
  def before_package(%Release{} = _release, _opts), do: nil
  def after_package(%Release{} = _release, _opts), do: nil
  def after_cleanup(%Release{} = _release, _opts), do: nil
end

