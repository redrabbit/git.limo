defmodule GitGud.Web.RepoView do
  @moduledoc false
  use GitGud.Web, :view

  alias GitGud.User
  alias GitGud.Repo

  @spec sort_repos([Repo.t]) :: [Repo.t]
  def sort_repos(repos), do: Enum.reverse(Enum.sort_by(repos, &(elem(&1, 0).pushed_at)))

  @spec title(atom, map) :: binary
  def title(:index, %{current_user: %User{id: user_id}, user: %User{id: user_id}}), do: "Your repositories"
  def title(:index, %{user: user}), do: "Repositories · #{user.login} (#{user.name})"
  def title(action, _assigns) when action in [:new, :create], do: "New repository"
  def title(action, %{repo: repo}) when action in [:edit, :update], do: "Settings · #{repo.owner.login}/#{repo.name}"
end
