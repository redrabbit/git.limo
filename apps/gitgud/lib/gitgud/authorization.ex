defmodule GitGud.Authorization do
  @moduledoc """
  Conveniences for authorization and resource loading.
  """

  alias GitGud.User

  @doc """
  Returns `true` if `user` is allowed to perform `action` on `resource`; otherwhise returns `false`.
  """
  @spec authorized?(User.t | nil, GitGud.AuthorizationPolicies.t, atom, keyword) :: boolean
  def authorized?(user, resource, action, opts \\ []) do
    GitGud.AuthorizationPolicies.can?(resource, user, action, Map.new(opts))
  end

  @doc """
  Enforces the authorization policy.
  """
  @spec enforce_policy(User.t | nil, GitGud.AuthorizationPolicies.t, atom, keyword) :: {:ok, GitGud.AuthorizationPolicies.t} | {:error, :unauthorized}
  def enforce_policy(user, resource, action, opts \\ []) do
    if authorized?(user, resource, action, opts),
      do: {:ok, resource},
    else: {:error, :unauthorized}
  end

  @doc """
  Same as `enforce_policy/3` but returns the `resource` or `default` if the policy cannot be enforced.
  """
  @spec enforce_policy!(User.t | nil, GitGud.AuthorizationPolicies.t, atom, any, keyword) :: GitGud.AuthorizationPolicies.t | any
  def enforce_policy!(user, resource, action, default \\ nil, opts \\ []) do
    case enforce_policy(user, resource, action, opts) do
      {:ok, resource} -> resource
      {:error, :unauthorized} -> default
    end
  end

  @doc """
  Filters the given list of `resources`, i.e. returns only those for which `authorized?/3` applies.
  """
  @spec filter(User.t | nil, [GitGud.AuthorizationPolicies.t], atom, keyword) :: [GitGud.AuthorizationPolicies.t]
  def filter(user, resources, action, opts \\ []) do
    Enum.filter(resources, &authorized?(user, &1, action, opts))
  end
end

defimpl GitGud.AuthorizationPolicies, for: Any do
  def can?(_resource, _user, _action, _opts), do: false
end
