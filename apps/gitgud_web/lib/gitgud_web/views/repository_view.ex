defmodule GitGud.Web.RepositoryView do
  @moduledoc false
  use GitGud.Web, :view

  def branch_with_path(branch, repo) do
    Map.put(branch, :path, repository_path(GitGud.Web.Endpoint, :tree, repo.owner, repo, branch.shorthand, []))
  end
end
