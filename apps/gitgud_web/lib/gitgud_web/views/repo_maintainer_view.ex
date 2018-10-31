defmodule GitGud.Web.RepoMaintainerView do
  @moduledoc false
  use GitGud.Web, :view

  alias GitGud.RepoMaintainer

  @spec permission_select(Phoenix.HTML.Form.t, atom, RepoMaintainer.t) :: binary
  def permission_select(form, key, maintainer) do
    select(form, key, ["admin", "read", "write"], selected: maintainer.permission)
  end

  @spec title(atom, map) :: binary
  def title(:index, %{repo: repo}), do: "Maintainers · #{repo.owner.username}/#{repo.name}"
end
