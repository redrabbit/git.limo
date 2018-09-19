defmodule GitGud.Web.UserProfileView do
  @moduledoc false
  use GitGud.Web, :view

  @spec title(atom, map) :: binary
  def title(:show, %{user: user}), do: "#{user.username} (#{user.name})"
end

