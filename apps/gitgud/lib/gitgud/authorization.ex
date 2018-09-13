defmodule GitGud.Authorization do
  @moduledoc """
  Conveniences for authorization and resource loading.
  """

  alias GitGud.User

  @doc """
  Returns `true` if `user` has the permission to perform `action` on `resource`; otherwhise returns `false`.
  """
  @spec authorized?(User.t | nil, GitGud.AuthorizationPolicies.t, atom) :: boolean
  def authorized?(user, resource, action) do
    GitGud.AuthorizationPolicies.can?(resource, user, action)
  end

  @doc """
  Enforces the authorization policy.
  """
  @spec enforce_policy(User.t | nil, GitGud.AuthorizationPolicies.t, atom) :: {:ok, GitGud.AuthorizationPolicies.t} | {:error, :unauthorized}
  def enforce_policy(user, resource, action) do
    if authorized?(user, resource, action),
      do: {:ok, resource},
    else: {:error, :unauthorized}
  end

  @doc """
  Same as `enforce_policy/3` but returns the `resource` or `default` if the policy cannot be enforced.
  """
  @spec enforce_policy!(User.t | nil, GitGud.AuthorizationPolicies.t, atom, any) :: GitGud.AuthorizationPolicies.t | any
  def enforce_policy!(user, resource, action, default \\ nil) do
    case enforce_policy(user, resource, action) do
      {:ok, resource} -> resource
      {:error, :unauthorized} -> default
    end
  end
end

defimpl GitGud.AuthorizationPolicies, for: Any do
  def can?(_resource, _user, _action), do: false
end
