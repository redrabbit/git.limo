alias GitRekt.GitAgent
alias GitGud.{Repo, RepoQuery, GitCommit}

Logger.configure(level: :info)

repo = RepoQuery.user_repo "redrabbit", "elixir"
repo = Repo.load_agent! repo

{:ok, head} = GitAgent.head repo

Benchee.run %{
  "revwalk" =>
    fn -> {:ok, hist} = GitAgent.history repo, head; Enum.count hist end,
  "postgres" =>
    fn -> {:ok, _count} = GitCommit.count_ancestors repo.id, head.oid end
}
