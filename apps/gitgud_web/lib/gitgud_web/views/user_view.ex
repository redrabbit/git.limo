defmodule GitGud.Web.UserView do
  @moduledoc false
  use GitGud.Web, :view

  alias GitGud.User

  @spec title(atom, map) :: binary
  def title(:show, %{current_user: %User{id: user_id}, user: %User{id: user_id}}), do: "Your profile"
  def title(:show, %{user: user}), do: "#{user.login} (#{user.name})"
  def title(:new, _assigns), do: "Register"
  def title(:edit_profile, _assigns), do: "Settings · Profile"
  def title(:edit_password, _assigns), do: "Settings · Password"
  def title(:reset_password, _assigns), do: "Settings · Reset Password"
end
