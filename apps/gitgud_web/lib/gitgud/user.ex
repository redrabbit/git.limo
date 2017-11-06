defimpl Phoenix.Param, for: GitGud.User do
  def to_param(user), do: user.username
end
