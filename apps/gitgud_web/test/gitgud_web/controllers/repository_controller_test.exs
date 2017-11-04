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
      conn = post conn, repository_path(conn, :create, user), repository: params
      assert %{"path" => path} = json_response(conn, 201)["data"]

      conn = get conn, repository_path(conn, :show, user, path)
      assert json_response(conn, 200)["data"] == %{
        "owner" => user.username,
        "path" => @valid_attrs.path,
        "name" => @valid_attrs.name,
        "description" => @valid_attrs.description}
    end

    test "renders errors when data is invalid", %{conn: conn, user: user} do
      params = Map.put(@valid_attrs, :owner_id, user.id)
      conn = post conn, repository_path(conn, :create, user), repository: %{params|path: "foo$bar"}
      assert "has invalid format" in json_response(conn, 422)["errors"]["path"]
    end
  end

  describe "index" do
    setup [:create_repository]

    test "lists all repositories", %{conn: conn, user: user} do
      conn = get conn, repository_path(conn, :index, user)
      assert json_response(conn, 200)["data"] == [%{
        "owner" => user.username,
        "path" => @valid_attrs.path,
        "name" => @valid_attrs.name,
        "description" => @valid_attrs.description}]
    end
  end

  describe "update repository" do
    setup [:create_repository]

    test "renders repository when data is valid", %{conn: conn, user: user, repo: %Repo{path: path} = repo} do
      name = "My Super Awesome Project"
      conn = put conn, repository_path(conn, :update, user, repo), repository: %{"name" => name}
      assert %{"path" => ^path} = json_response(conn, 200)["data"]

      conn = get conn, repository_path(conn, :show, user, repo)
      assert json_response(conn, 200)["data"] == %{
        "owner" => user.username,
        "path" => @valid_attrs.path,
        "name" => name,
        "description" => @valid_attrs.description}
    end

    test "renders errors when data is invalid", %{conn: conn, user: user, repo: repo} do
      params = %{"path" => "foo$bar"}
      conn = put conn, repository_path(conn, :update, user, repo), repository: params
      assert "has invalid format" in json_response(conn, 422)["errors"]["path"]
    end
  end

  describe "delete repository" do
    setup [:create_repository]

    test "deletes chosen repository", %{conn: conn, user: user, repo: repo} do
      conn = delete conn, repository_path(conn, :delete, user, repo)
      assert response(conn, 204)
      conn = get conn, repository_path(conn, :show, user, repo)
      assert response(conn, 404)
    end
  end

  #
  # Helpers
  #

  defp create_repository %{user: user} do
    params = Map.put(@valid_attrs, :owner_id, user.id)
    {repo, _pid} = Repo.create! params
    {:ok, repo: repo}
  end
end
