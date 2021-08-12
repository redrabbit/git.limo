defmodule GitGud.Web.RepoView do
  @moduledoc false
  use GitGud.Web, :view

  alias GitGud.User

  @spec title(atom, map) :: binary
  def title(:index, %{current_user: %User{id: user_id}, user: %User{id: user_id}}), do: "Your repositories"
  def title(:index, %{user: user}), do: "Repositories · #{user.login} (#{user.name})"
  def title(action, _assigns) when action in [:new, :create], do: "New repository"
  def title(action, %{repo: repo}) when action in [:edit, :update], do: "Settings · #{repo.owner_login}/#{repo.name}"
end
