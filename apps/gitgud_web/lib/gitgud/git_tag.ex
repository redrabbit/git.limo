defimpl Phoenix.Param, for: GitGud.GitTag do
  def to_param(tag), do: tag.name
end
