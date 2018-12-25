defmodule GitGud.SmartHTTPBackendTest do
  use GitGud.DataCase
  use GitGud.DataFactory

  use Plug.Test

  alias GitGud.User
  alias GitGud.Repo
  alias GitGud.SmartHTTPBackend
  alias GitGud.SmartHTTPBackendRouter

  setup [:create_user, :create_repo]

  test "authenticates with valid credentials", %{user: user, repo: repo} do
    conn = conn(:get, "/info/refs", %{"user_name" => user.login, "repo_name" => repo.name})
    conn = put_req_header(conn, "authorization", "Basic " <> Base.encode64("#{user.login}:qwertz"))
    conn = SmartHTTPBackend.call(conn, [])
    assert conn.assigns.current_user == user
    assert conn.status == 200
  end

  test "fails to authenticates with invalid credentials", %{user: user, repo: repo} do
    conn = conn(:get, "/info/refs", %{"user_name" => user.login, "repo_name" => repo.name})
    conn = put_req_header(conn, "authorization", "Basic " <> Base.encode64("#{user.login}:qwerty"))
    conn = SmartHTTPBackend.call(conn, [])
    assert {"www-authenticate", ~s(Basic realm="GitGud")} in conn.resp_headers
    assert conn.status == 401
  end

  test "fails to calls backend without authentication header", %{user: user, repo: repo} do
    conn = conn(:get, "/info/refs", %{"user_name" => user.login, "repo_name" => repo.name})
    conn = SmartHTTPBackend.call(conn, [])
    assert {"www-authenticate", ~s(Basic realm="GitGud")} in conn.resp_headers
    assert conn.status == 401
  end

  describe "when repository is empty" do
    setup [:start_http_backend, :create_workdir]

    test "pushes initial commit", %{user: user, repo: repo, workdir: workdir} do
      readme_content = "##{repo.name}\r\n\r\n#{repo.description}"
      assert {_output, 0} = System.cmd("git", ["init"], cd: workdir)
      File.write!(Path.join(workdir, "README.md"), readme_content)
      assert {_output, 0} = System.cmd("git", ["add", "README.md"], cd: workdir)
      assert {_output, 0} = System.cmd("git", ["commit", "README.md", "-m", "Initial commit"], cd: workdir)
      assert {_output, 0} = System.cmd("git", ["remote", "add", "origin", "http://#{user.login}:qwertz@localhost:4001/#{user.login}/#{repo.name}"], cd: workdir)
      assert {_output, 0} = System.cmd("git", ["push", "--set-upstream", "origin", "--quiet", "master"], cd: workdir)
      assert {:ok, ref} = Repo.git_head(repo)
      assert {:ok, commit} = GitGud.GitReference.target(ref)
      assert {:ok, "Initial commit\n"} = GitGud.GitCommit.message(commit)
      assert {:ok, tree} = Repo.git_tree(commit)
      assert {:ok, tree_entry} = GitGud.GitTree.by_path(tree, "README.md")
      assert {:ok, blob} = GitGud.GitTreeEntry.target(tree_entry)
      assert {:ok, ^readme_content} = GitGud.GitBlob.content(blob)
    end

    test "pushes repository (~500 commits)", %{user: user, repo: repo, workdir: workdir} do
      assert {_output, 0} = System.cmd("git", ["clone", "--quiet", "https://github.com/almightycouch/gitgud.git", workdir])
      assert {_output, 0} = System.cmd("git", ["remote", "rm", "origin"], cd: workdir)
      assert {_output, 0} = System.cmd("git", ["remote", "add", "origin", "http://#{user.login}:qwertz@localhost:4001/#{user.login}/#{repo.name}"], cd: workdir)
      assert {_output, 0} = System.cmd("git", ["push", "--set-upstream", "origin", "--quiet", "master"], cd: workdir)
      assert {:ok, ref} = Repo.git_head(repo)
      output = GitRekt.Git.oid_fmt(ref.oid) <> "\n"
      assert {^output, 0} = System.cmd("git", ["rev-parse", "HEAD"], cd: workdir)
    end
  end

  describe "when repository exists" do
    setup [:start_http_backend, :clone_from_github, :create_workdir]

    test "clones repository (~500 commits)", %{user: user, repo: repo, workdir: workdir} do
      assert {_output, 0} = System.cmd("git", ["clone", "--bare", "--quiet", "http://#{user.login}:qwertz@localhost:4001/#{user.login}/#{repo.name}", workdir])
      assert {:ok, ref} = Repo.git_head(repo)
      output = GitRekt.Git.oid_fmt(ref.oid) <> "\n"
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
      File.rmdir(Path.join(Repo.root_path, user.login))
    end
    Map.put(context, :user, user)
  end

  defp create_repo(context) do
    repo = Repo.create!(factory(:repo, context.user))
    on_exit fn ->
      File.rm_rf(Repo.workdir(repo))
    end
    Map.put(context, :repo, repo)
  end

  defp clone_from_github(context) do
    File.rm_rf!(Repo.workdir(context.repo))
    {_output, 0} = System.cmd("git", ["clone", "--bare", "--quiet", "https://github.com/almightycouch/gitgud.git", context.repo.name], cd: Path.join(Repo.root_path(), context.user.login))
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
