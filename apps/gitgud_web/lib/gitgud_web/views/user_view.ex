defmodule GitGud.Web.UserView do
  @moduledoc false
  use GitGud.Web, :view

  alias GitGud.Auth

  import Ecto.Changeset, only: [fetch_field: 2]

  @spec readonly_email?(Ecto.Changeset.t) :: boolean
  def readonly_email?(changeset) do
    case fetch_field(changeset, :auth) do
      {:changes, %Auth{providers: providers}} ->
        is_list(providers) && !Enum.empty?(providers)
      {:data, %Auth{providers: providers}} ->
        is_list(providers) && !Enum.empty?(providers)
      :error ->
        false
    end
  end

  @spec title(atom, map) :: binary
  def title(:show, %{user: user}), do: "#{user.login} (#{user.name})"
  def title(:new, _assigns), do: "Register"
  def title(:edit_profile, _assigns), do: "Profile"
  def title(:edit_password, _assigns), do: "Password"
  def title(:reset_password, _assigns), do: "Reset Password"
end
