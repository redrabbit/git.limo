defmodule GitGud.Web.RepoControllerTest do
  use GitGud.Web.ConnCase

  import GitGud.Web.AuthenticationPlug, only: [generate_token: 1]

  alias GitGud.Repo
  alias GitGud.User

  @valid_attrs %{path: "project-awesome", name: "My Awesome Project", description: "Awesome things are going on here!"}

  setup %{conn: conn} do
    user = User.register!(name: "Mario Flach", username: "redrabbit", email: "m.flach@almightycouch.com", password: "test1234")
    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "Bearer #{generate_token(user.id)}")
    {:ok, conn: conn, user: user}
  end

  describe "create repository" do
    test "renders repository when data is valid", %{conn: conn, user: user} do
      params = Map.put(@valid_attrs, :owner_id, user.id)
      conn = post conn, codebase_path(conn, :create, user), repo: params
      assert %{"path" => path} = json_response(conn, 201)

      conn = get conn, codebase_path(conn, :show, user, path)
      assert json_response(conn, 200) == %{
        "owner" => user.username,
        "path" => @valid_attrs.path,
        "name" => @valid_attrs.name,
        "description" => @valid_attrs.description,
        "url" => "http://localhost:4001/api/users/redrabbit/repos/project-awesome"}
    end

    test "renders errors when data is invalid", %{conn: conn, user: user} do
      params = Map.put(@valid_attrs, :owner_id, user.id)
      conn = post conn, codebase_path(conn, :create, user), repo: %{params|path: "foo$bar"}
      assert "has invalid format" in json_response(conn, 422)["errors"]["path"]
    end
  end

  describe "index" do
    setup [:create_repository]

    test "lists all repositories", %{conn: conn, user: user} do
      conn = get conn, codebase_path(conn, :index, user)
      assert json_response(conn, 200) == [%{
        "owner" => user.username,
        "path" => @valid_attrs.path,
        "name" => @valid_attrs.name,
        "description" => @valid_attrs.description,
        "url" => "http://localhost:4001/api/users/redrabbit/repos/project-awesome"}]
    end
  end

  describe "update repository" do
    setup [:create_repository]

    test "renders repository when data is valid", %{conn: conn, user: user, repo: %Repo{path: path} = repo} do
      name = "My Super Awesome Project"
      conn = put conn, codebase_path(conn, :update, user, repo), repo: %{"name" => name}
      assert %{"path" => ^path} = json_response(conn, 200)

      conn = get conn, codebase_path(conn, :show, user, repo)
      assert json_response(conn, 200) == %{
        "owner" => user.username,
        "path" => @valid_attrs.path,
        "name" => name,
        "description" => @valid_attrs.description,
        "url" => "http://localhost:4001/api/users/redrabbit/repos/project-awesome"}
    end

    test "renders errors when data is invalid", %{conn: conn, user: user, repo: repo} do
      params = %{"path" => "foo$bar"}
      conn = put conn, codebase_path(conn, :update, user, repo), repo: params
      assert "has invalid format" in json_response(conn, 422)["errors"]["path"]
    end
  end

  describe "delete repository" do
    setup [:create_repository]

    test "deletes chosen repository", %{conn: conn, user: user, repo: repo} do
      conn = delete conn, codebase_path(conn, :delete, user, repo)
      assert response(conn, 204)
      conn = get conn, codebase_path(conn, :show, user, repo)
      assert response(conn, 404)
    end
  end

  describe "git branches" do
    setup [:create_repository, :fill_repository]

    test "lists all branches sorted alphabeticaly ", %{conn: conn, user: user, repo: repo} do
      conn = get conn, codebase_path(conn, :branch_list, user, repo)
       assert ["awesome", "master"] = Enum.map(json_response(conn, 200), &(&1["name"]))
    end

    test "renders single branch", %{conn: conn, user: user, repo: repo} do
      conn = get conn, codebase_path(conn, :branch, user, repo, "awesome")
      assert {"name", "awesome"} in json_response(conn, 200)
      conn = get conn, codebase_path(conn, :branch, user, repo, "master")
      assert {"name", "master"} in json_response(conn, 200)
    end

    test "renders error when branch is invalid", %{conn: conn, user: user, repo: repo} do
      conn = get conn, codebase_path(conn, :branch, user, repo, "lost")
      assert "no reference found for shorthand 'lost'" = json_response(conn, 400)["errors"]["details"]
    end
  end

  describe "git tags" do
    setup [:create_repository, :fill_repository]

    test "lists all tags sorted ascendingly", %{conn: conn, user: user, repo: repo} do
      conn = get conn, codebase_path(conn, :tag_list, user, repo)
      assert [%{"name" => "v0.0.1", "type" => "lightweight"}, %{"name" => "v0.0.2", "type" => "annotated"}] = json_response(conn, 200)
    end

    test "renders single tag", %{conn: conn, user: user, repo: repo} do
      conn = get conn, codebase_path(conn, :tag, user, repo, "v0.0.1")
      assert %{"name" => "v0.0.1", "type" => "lightweight"} = json_response(conn, 200)
      conn = get conn, codebase_path(conn, :tag, user, repo, "v0.0.2")
      assert %{"name" => "v0.0.2", "type" => "annotated"} = json_response(conn, 200)
    end

    test "renders error when tag is invalid", %{conn: conn, user: user, repo: repo} do
      conn = get conn, codebase_path(conn, :tag, user, repo, "v0.0.0")
      assert "no reference found for shorthand 'v0.0.0'" = json_response(conn, 400)["errors"]["details"]
    end
  end

  describe "git commits" do
    setup [:create_repository, :fill_repository]

    test "lists all commits sorted descendingly", %{conn: conn, user: user, repo: repo} do
      conn = get conn, codebase_path(conn, :revwalk, user, repo, "master")
      assert ["Add setup.sh\n", "Add LICENCE\n", "Add README\n"] == Enum.map(json_response(conn, 200), &(&1["message"]))
      conn = get conn, codebase_path(conn, :revwalk, user, repo, "v0.0.1")
      assert ["Add LICENCE\n", "Add README\n"] == Enum.map(json_response(conn, 200), &(&1["message"]))
    end

    test "renders error when spec is invalid", %{conn: conn, user: user, repo: repo} do
      conn = get conn, codebase_path(conn, :revwalk, user, repo, "unknown")
      assert "revspec 'unknown' not found" = json_response(conn, 400)["errors"]["details"]
    end
  end

  describe "git tree" do
    setup [:create_repository, :fill_repository]

    test "lists files in tree", %{conn: conn, user: user, repo: repo} do
      conn = get conn, codebase_path(conn, :browse_tree, user, repo, "master", [])
      assert Enum.all?(json_response(conn, 200), &(&1["type"] == "blob"))
      assert ["LICENCE", "README", "setup.sh"] == Enum.map(json_response(conn, 200), &(&1["path"]))
    end

    test "renders error when spec is invalid", %{conn: conn, user: user, repo: repo} do
      conn = get conn, codebase_path(conn, :browse_tree, user, repo, "unknown", [])
      assert "revspec 'unknown' not found" = json_response(conn, 400)["errors"]["details"]
    end

    test "renders error when path is invalid", %{conn: conn, user: user, repo: repo} do
      conn = get conn, codebase_path(conn, :browse_tree, user, repo, "master", ["test"])
      assert "the path 'test' does not exist in the given tree" = json_response(conn, 400)["errors"]["details"]
    end
  end

  #
  # Helpers
  #

  defp create_repository %{user: user} do
    params = Map.put(@valid_attrs, :owner_id, user.id)
    File.rm_rf!(Repo.workdir(struct(Repo, params)))
    {repo, handle} = Repo.create! params, bare: false
    {:ok, repo: repo, handle: handle}
  end

  defp fill_repository %{user: user, repo: repo} do
    repo_path = Repo.workdir(repo)
    assert File.write!(Path.join(repo_path, "README"), "# #{repo.name}\n#{repo.description}")
    git_add(repo_path, ["README"])
    git_commit(repo_path, "Add README")
    assert File.write!(Path.join(repo_path, "LICENCE"), "Copyright (c) 2017 #{user.name} <#{user.email}>")
    git_add(repo_path, ["LICENCE"])
    git_commit(repo_path, "Add LICENCE")
    git_tag_lightweight(repo_path, "v0.0.1")
    assert File.write!(Path.join(repo_path, "setup.sh"), "echo #{repo_path}")
    git_add(repo_path, ["setup.sh"])
    git_commit(repo_path, "Add setup.sh")
    git_tag_annotated(repo_path, "v0.0.2")
    git_new_branch(repo_path, "awesome")
    :ok
  end

  defp git_tag_lightweight(repo_path, tag) do
    assert {_msg, 0} = System.cmd("git", ["tag", tag], cd: repo_path, stderr_to_stdout: true)
  end

  defp git_tag_annotated(repo_path, tag) do
    assert {_msg, 0} = System.cmd("git", ["tag", "-a", tag, "-m", "Release #{tag}"], cd: repo_path, stderr_to_stdout: true)
  end

  defp git_add(repo_path, filenames) do
    assert {_msg, 0} = System.cmd("git", List.flatten(["add", filenames]), cd: repo_path, stderr_to_stdout: true)
  end

  defp git_commit(repo_path, msg) do
    assert {_msg, 0} = System.cmd("git", ["commit", "-a", "-m", msg], cd: repo_path, stderr_to_stdout: true)
  end

  defp git_new_branch(repo_path, branch) do
    assert {_msg, 0} = System.cmd("git", ["branch", branch], cd: repo_path, stderr_to_stdout: true)
  end
end
