defmodule GitGud.Web.RepoView do
  @moduledoc false
  use GitGud.Web, :view

  alias GitGud.User
  alias GitGud.Repo

  @spec sort_user_repos([Repo.t]) :: [Repo.t]
  def sort_user_repos(repos) do
    Enum.sort_by(repos, &(&1.pushed_at), fn
      %NaiveDateTime{} = one, %NaiveDateTime{} = two ->
        NaiveDateTime.compare(one, two) != :lt
      one, two ->
        one <= two
    end)
  end

  @spec title(atom, map) :: binary
  def title(:index, %{current_user: %User{id: user_id}, user: %User{id: user_id}}), do: "Your repositories"
  def title(:index, %{user: user}), do: "Repositories · #{user.login} (#{user.name})"
  def title(action, _assigns) when action in [:new, :create], do: "New repository"
  def title(action, %{repo: repo}) when action in [:edit, :update], do: "Settings · #{repo.owner.login}/#{repo.name}"
end
