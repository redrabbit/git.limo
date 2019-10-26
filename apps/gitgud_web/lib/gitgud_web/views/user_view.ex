defmodule GitGud.Web.UserView do
  @moduledoc false
  use GitGud.Web, :view

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
  def title(:show, %{user: user}), do: "#{user.login} (#{user.name})"
  def title(:new, _assigns), do: "Register"
  def title(:edit_profile, _assigns), do: "Settings · Profile"
  def title(:edit_password, _assigns), do: "Settings · Password"
  def title(:reset_password, _assigns), do: "Settings · Reset Password"
end
