import Phoenix.HTML.Tag

defimpl Phoenix.Param, for: GitGud.GitCommit do
  def to_param(commit), do: GitRekt.Git.oid_fmt(commit.oid)
end

defimpl Phoenix.HTML.Safe, for: GitGud.GitCommit do
  def to_iodata(commit) do
    Phoenix.HTML.Safe.to_iodata(content_tag(:span, GitRekt.Git.oid_fmt_short(commit.oid), class: "commit"))
  end
end
