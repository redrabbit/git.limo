defmodule GitGud.Web.UserView do
  @moduledoc false
  use GitGud.Web, :view

  @spec title(atom, map) :: binary
  def title(:new, _assigns), do: "Register"
  def title(:edit_profile, _assigns), do: "Profile"
  def title(:edit_password, _assigns), do: "Password"
  def title(:show, %{user: user}), do: "#{user.username} (#{user.name})"
end
