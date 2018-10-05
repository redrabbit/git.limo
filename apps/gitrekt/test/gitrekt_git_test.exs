defmodule GitRekt.GitTest do
  use ExUnit.Case

  alias GitRekt.Git

  setup do
    {:ok, repo} = Git.repository_init("priv/test", false)

    on_exit(fn ->
      File.rm_rf!(Git.repository_get_path(repo))
    end)

    {:ok, %{repo: repo}}
  end

  test "ensures repository is valid", %{repo: repo} do
    workdir = Path.expand("priv/test")
    gitpath = Path.join(workdir, ".git")
    refute Git.repository_bare?(repo)
    assert Git.repository_get_workdir(repo) == "#{workdir}/"
    assert Git.repository_get_path(repo) == "#{gitpath}/"
  end
end
