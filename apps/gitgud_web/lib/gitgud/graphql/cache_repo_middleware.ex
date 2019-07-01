defmodule GitGud.GraphQL.CacheRepoMiddleware do
  @moduledoc false

  @behaviour Absinthe.Middleware

  alias GitRekt.GitAgent

  def call(resolution, repo) do
    case GitAgent.attach(repo) do
      {:ok, repo} ->
        resolution
        |> Map.update!(:context, &Map.put(&1, :repo, repo))
        |> Absinthe.Resolution.put_result({:ok, repo})
      {:error, reason} ->
        Absinthe.Resolution.put_result(resolution, {:error, reason})
    end
  end
end
