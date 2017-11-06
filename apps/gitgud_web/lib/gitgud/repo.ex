defimpl Phoenix.Param, for: GitGud.Repo do
  def to_param(repo), do: repo.path
end

