alias GitRekt.GitAgent
alias GitGud.{DB, DBQueryable, CommitQuery, RepoQuery}

Logger.configure level: :info

repo = RepoQuery.user_repo "redrabbit", "git-limo"
{:ok, head} = GitAgent.head repo

Benchee.run %{
  "revwalk" =>
    fn ->
      {:ok, hist} = GitAgent.history repo, head
      Enum.count hist
    end,
  "postgres" =>
    fn ->
      query = DBQueryable.query {CommitQuery, :ancestors_count_query}, [repo, head.oid]
      DB.one query, timeout: :infinity
    end
}
