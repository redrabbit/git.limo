defprotocol GitGud.AuthorizationPolicies do
  @moduledoc """
  Protocol for implementing resource authorization policies.
  """

  @fallback_to_any true

  @doc """
  Returns `true` if `user` is allowed to perform `action` on `resource`; otherwhise returns `false`.
  """
  def can?(resource, user, action)
end
