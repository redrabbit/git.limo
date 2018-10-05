defimpl Phoenix.Param, for: GitGud.GitCommit do
  def to_param(commit), do: GitRekt.Git.oid_fmt(commit.oid)
end
