defmodule GitGud.Web.MaintainerView do
  @moduledoc false
  use GitGud.Web, :view

  alias GitGud.Maintainer

  @spec permission_select(Phoenix.HTML.Form.t, atom, Maintainer.t) :: binary
  def permission_select(form, key, maintainer) do
    select(form, key, ["admin", "read", "write"], selected: maintainer.permission)
  end

  @spec title(atom, map) :: binary
  def title(_action, %{repo: repo}), do: "Maintainers · #{repo.owner.login}/#{repo.name}"
end
