defmodule GitGud.SmartHTTPBackendTest do
  use GitGud.DataCase
  use GitGud.DataFactory

  use Plug.Test

  alias GitRekt.Git
  alias GitRekt.GitRepo
  alias GitRekt.GitAgent

  alias GitGud.User
  alias GitGud.Repo
  alias GitGud.RepoStorage
  alias GitGud.SmartHTTPBackendRouter

  setup [:create_user, :create_repo]

  test "authenticates with valid credentials", %{user: user, repo: repo} do
    conn = conn(:get, "/#{repo.owner_login}/#{repo.name}.git/info/refs?service=git-receive-pack")
    conn = put_req_header(conn, "authorization", "Basic " <> Base.encode64("#{user.login}:qwertz"))
    conn = SmartHTTPBackendRouter.call(conn, [])
    assert conn.assigns.current_user == user
    assert conn.status == 200
  end

  test "fails to call backend without authentication header", %{repo: repo} do
    conn = conn(:get, "/#{repo.owner_login}/#{repo.name}.git/info/refs?service=git-receive-pack")
    conn = SmartHTTPBackendRouter.call(conn, :discover)
    assert conn.status == 401
    assert {"www-authenticate", ~s(Basic realm="GitGud")} in conn.resp_headers
  end

  test "fails to authenticates with invalid credentials", %{user: user, repo: repo} do
    conn = conn(:get, "/#{repo.owner_login}/#{repo.name}.git/info/refs?service=git-receive-pack")
    conn = put_req_header(conn, "authorization", "Basic " <> Base.encode64("#{user.login}:qwerty"))
    conn = SmartHTTPBackendRouter.call(conn, :discover)
    assert conn.status == 401
    assert {"www-authenticate", ~s(Basic realm="GitGud")} in conn.resp_headers
  end

  test "fails to advertise references to dump clients", %{repo: repo} do
    conn = conn(:get, "/#{repo.owner_login}/#{repo.name}.git/info/refs")
    conn = SmartHTTPBackendRouter.call(conn, :discover)
    assert conn.status == 400
  end

  describe "when repository is empty" do
    setup [:start_http_backend, :create_workdir]

    @tag :skip
    test "pushes initial commit", %{user: user, repo: repo, workdir: workdir} do
      readme_content = "##{repo.name}\r\n\r\n#{repo.description}"
      assert {_output, 0} = System.cmd("git", ["init", "-b", "main"], cd: workdir)
      assert {_output, 0} = System.cmd("git", ["config", "user.name", "testbot"], cd: workdir)
      assert {_output, 0} = System.cmd("git", ["config", "user.email", "no-reply@git.limo"], cd: workdir)
      File.write!(Path.join(workdir, "README.md"), readme_content)
      assert {_output, 0} = System.cmd("git", ["add", "README.md"], cd: workdir)
      assert {_output, 0} = System.cmd("git", ["commit", "README.md", "-m", "Initial commit"], cd: workdir)
      assert {_output, 0} = System.cmd("git", ["remote", "add", "origin", "http://#{user.login}:qwertz@localhost:4001/#{user.login}/#{repo.name}.git"], cd: workdir)
      assert {"Everything up-to-date\n", 1} = System.cmd("git", ["push", "--set-upstream", "origin", "main"], cd: workdir, stderr_to_stdout: true)
      assert {:ok, agent} = GitRepo.get_agent(repo)
      assert {:ok, head} = GitAgent.head(agent)
      assert {:ok, commit} = GitAgent.peel(agent, head)
      assert {:ok, "Initial commit\n"} = GitAgent.commit_message(agent, commit)
      assert {:ok, tree} = GitAgent.tree(agent, commit)
      assert {:ok, tree_entry} = GitAgent.tree_entry_by_path(agent, tree, "README.md")
      assert {:ok, blob} = GitAgent.peel(agent, tree_entry)
      assert {:ok, ^readme_content} = GitAgent.blob_content(agent, blob)
    end

    @tag :skip
    test "pushes repository", %{user: user, repo: repo, workdir: workdir} do
      assert {_output, 0} = System.cmd("git", ["clone", "--quiet", "https://github.com/almightycouch/gitgud.git", workdir])
      assert {_output, 0} = System.cmd("git", ["branch", "-m", "master", "main"], cd: workdir)
      assert {_output, 0} = System.cmd("git", ["remote", "rm", "origin"], cd: workdir)
      assert {_output, 0} = System.cmd("git", ["remote", "add", "origin", "http://#{user.login}:qwertz@localhost:4001/#{user.login}/#{repo.name}.git"], cd: workdir)
      assert {"Everything up-to-date\n", 1} = System.cmd("git", ["push", "--set-upstream", "origin", "main"], cd: workdir, stderr_to_stdout: true)
      assert {:ok, agent} = GitRepo.get_agent(repo)
      assert {:ok, head} = GitAgent.head(agent)
      output = Git.oid_fmt(head.oid) <> "\n"
      assert {^output, 0} = System.cmd("git", ["rev-parse", "HEAD"], cd: workdir)
    end
  end

  describe "when repository exists" do
    setup [:start_http_backend, :clone_from_github, :create_workdir]

    @tag :skip
    test "clones repository", %{user: user, repo: repo, workdir: workdir} do
      assert {_output, 0} = System.cmd("git", ["clone", "--bare", "--quiet", "http://#{user.login}:qwertz@localhost:4001/#{user.login}/#{repo.name}.git", workdir], stderr_to_stdout: true)
      assert {:ok, agent} = GitRepo.get_agent(repo)
      assert {:ok, head} = GitAgent.head(agent)
      output = Git.oid_fmt(head.oid) <> "\n"
      assert {^output, 0} = System.cmd("git", ["rev-parse", "HEAD"], cd: workdir)
    end
  end

  #
  # Helpers
  #

  defp start_http_backend(_context) do
    {:ok, _pid} = start_supervised({Plug.Cowboy, scheme: :http, plug: SmartHTTPBackendRouter, options: [port: 4001]})
#   on_exit fn ->
#     :ok = stop_supervised(pid)
#   end
    :ok
  end

  defp create_user(context) do
    user = User.create!(factory(:user))
    on_exit fn ->
      File.rmdir(Path.join(Keyword.fetch!(Application.get_env(:gitgud, RepoStorage), :git_root), user.login))
    end
    Map.put(context, :user, user)
  end

  defp create_repo(context) do
    repo = Repo.create!(context.user, factory(:repo))
    on_exit fn ->
      File.rm_rf(RepoStorage.workdir(repo))
    end
    Map.put(context, :repo, repo)
  end

  defp clone_from_github(context) do
    File.rm_rf!(RepoStorage.workdir(context.repo))
    {_output, 0} = System.cmd("git", ["clone", "--bare", "--quiet", "https://github.com/almightycouch/gitgud.git", context.repo.name], cd: Path.join(Keyword.fetch!(Application.get_env(:gitgud, RepoStorage), :git_root), context.user.login))
    :ok
  end

  defp create_workdir(context) do
    workdir = Path.join(System.tmp_dir!(), context.repo.name)
    File.mkdir!(workdir)
    on_exit fn ->
      File.rm_rf(workdir)
    end
    Map.put(context, :workdir, workdir)
  end
end
