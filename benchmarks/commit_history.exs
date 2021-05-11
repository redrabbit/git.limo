alias GitRekt.GitAgent

Logger.configure level: :info

repo = GitGud.RepoQuery.user_repo "redrabbit", "git-limo"

#{:ok, pool} = GitGud.RepoPool.start_agent_pool(repo)

Benchee.run %{
  "unwrap" =>
    fn ->
      Task.await_many(
        for i <- 0..10 do
          Task.async(fn ->
            with {:ok, agent} <- GitAgent.unwrap(repo),
                 {:ok, {commit, _ref}} <- GitAgent.revision(agent, "HEAD~#{i}"),
                 {:ok, count} <- GitAgent.history_count(agent, commit) do
              {:ok, count}
            end
          end)
        end
      )
    end,
  "checkout" =>
    fn ->
      Task.await_many(
        for i <- 0..10 do
          Task.async(fn ->
            GitGud.RepoPool.checkout(repo, fn agent ->
              with {:ok, {commit, _ref}} <- GitAgent.revision(agent, "HEAD~#{i}"),
                  {:ok, count} <- GitAgent.history_count(agent, commit) do
                {:ok, count}
              end
            end)
          end)
        end
      )
    end,
}
