defmodule GitGud.Web.RepoView do
  @moduledoc false
  use GitGud.Web, :view

  def render("index.json", %{repositories: repositories}) do
    %{data: render_many(repositories, __MODULE__, "repository.json")}
  end

  def render("show.json", %{repository: repository}) do
    %{data: render_one(repository, __MODULE__, "repository.json")}
  end

  def render("repository.json", %{repository: repository}) do
    %{owner: repository.owner.username,
      name: repository.name,
      path: repository.path,
      description: repository.description}
  end
end
