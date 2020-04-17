defmodule GitGud.Web.RepoView do
  @moduledoc false
  use GitGud.Web, :view

  @spec title(atom, map) :: binary
  def title(action, _assigns) when action in [:new, :create], do: "New repository"
  def title(action, %{repo: repo}) when action in [:edit, :update], do: "Settings · #{repo.owner.login}/#{repo.name}"
end
