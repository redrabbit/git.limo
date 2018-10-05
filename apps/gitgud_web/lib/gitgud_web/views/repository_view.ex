defmodule GitGud.Web.RepositoryView do
  @moduledoc false
  use GitGud.Web, :view

  @spec comma_separated_maintainers([GitGud.User.t()]) :: binary
  def comma_separated_maintainers(maintainers) do
    maintainers
    |> Enum.map(& &1.username)
    |> Enum.join(",")
  end

  @spec title(atom, map) :: binary
  def title(:new, _assigns), do: "Create a new repository"
  def title(:edit, %{repo: repo}), do: "Settings · #{repo.owner.username}/#{repo.name}"
end
