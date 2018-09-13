defprotocol GitGud.AuthorizationPolicies do
  @fallback_to_any true

  @doc """
  Returns `true` if `user` has the permission to perform `action` on `target`.
  """
  def can?(resource, user, action)
end
