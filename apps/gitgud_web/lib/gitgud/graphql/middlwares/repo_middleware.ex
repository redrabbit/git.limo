defmodule GitGud.GraphQL.RepoMiddleware do
  @moduledoc false

  @behaviour Absinthe.Middleware

  def call(resolution, repo) do
    resolution
    |> Map.update!(:context, &Map.put(&1, :repo, repo))
    |> Absinthe.Resolution.put_result({:ok, repo})
  end
end
