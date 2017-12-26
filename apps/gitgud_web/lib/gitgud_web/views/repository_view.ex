defmodule GitGud.Web.RepositoryView do
  @moduledoc false
  use GitGud.Web, :view

  def render("repository_list.json", %{repositories: repositories}) do
    render_many(repositories, __MODULE__, "repository.json")
  end

  def render("repository.json", %{repository: repository}) do
    %{owner: repository.owner.username,
      name: repository.name,
      path: repository.path,
      description: repository.description,
      url: repository_url(GitGud.Web.Endpoint, :show, repository.owner, repository.path)}
  end
end
