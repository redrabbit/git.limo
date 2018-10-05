defimpl Phoenix.Param, for: GitGud.GitReference do
  def to_param(ref), do: ref.name
end
