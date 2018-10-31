defmodule GitGud.Web.RepoView do
  @moduledoc false
  use GitGud.Web, :view

  @spec title(atom, map) :: binary
  def title(:new, _assigns), do: "Create a new repository"
  def title(:edit, %{repo: repo}), do: "Settings · #{repo.owner.username}/#{repo.name}"
end
