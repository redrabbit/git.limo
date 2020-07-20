defmodule GitGud.Repo do
  @moduledoc """
  Git repository schema and helper functions.
  """

  use Ecto.Schema

  alias Ecto.Multi

  alias GitRekt.GitAgent

  alias GitGud.DB
  alias GitGud.Issue
  alias GitGud.IssueLabel
  alias GitGud.Maintainer
  alias GitGud.User
  alias GitGud.RepoPool
  alias GitGud.RepoStorage

  import Ecto.Changeset

  schema "repositories" do
    belongs_to :owner, User
    field :name, :string
    field :public, :boolean, default: true
    field :description, :string
    has_many :issue_labels, IssueLabel, on_replace: :delete
    has_many :issues, Issue
    many_to_many :maintainers, User, join_through: Maintainer, on_replace: :delete
    many_to_many :contributors, User, join_through: "repositories_contributors", on_replace: :delete
    timestamps()
    field :pushed_at, :naive_datetime
  end

  @type t :: %__MODULE__{
    id: pos_integer,
    owner_id: pos_integer,
    owner: User.t,
    name: binary,
    public: boolean,
    description: binary,
    maintainers: [User.t],
    inserted_at: NaiveDateTime.t,
    updated_at: NaiveDateTime.t,
    pushed_at: NaiveDateTime.t,
  }

  @issue_labels %{
    "bug" => "ee0701",
    "question" => "cc317c",
    "duplicate" => "cccccc",
    "help wanted" => "33aa3f",
    "invalid" => "e6e6e6"
  }

  @doc """
  Creates a new repository.

  ```elixir
  {:ok, repo, git_handle} = GitGud.Repo.create(
    owner_id: user.id,
    name: "gitgud",
    description: "GitHub clone entirely written in Elixir.",
    public: true
  )
  ```

  This function validates the given `params` using `changeset/2`.
  """
  @spec create(map|keyword, keyword) :: {:ok, t} | {:error, Ecto.Changeset.t | term}
  def create(params, opts \\ []) do
    changeset = changeset(%__MODULE__{}, Map.new(params))
    multi =
      if Keyword.get(opts, :init, true),
        do: create_and_init_multi(changeset, Keyword.get(opts, :bare, true)),
      else: create_multi(changeset)
    case DB.transaction(multi) do
      {:ok, %{repo: repo, issue_labels: issue_labels}} ->
        {:ok, struct(repo, issue_labels: issue_labels, maintainers: [repo.owner])}
      {:error, :init, reason, _changes} ->
        {:error, reason}
      {:error, _name, changeset, _changes} ->
        {:error, changeset}
    end
  end

  @doc """
  Similar to `create/2`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec create!(map|keyword, keyword) :: t
  def create!(params, opts \\ []) do
    case create(params, opts) do
      {:ok, repo} -> repo
      {:error, changeset} -> raise Ecto.InvalidChangesetError, action: changeset.action, changeset: changeset
    end
  end

  @doc """
  Updates the given `repo` with the given `params`.

  ```elixir
  {:ok, repo} = GitGud.Repo.update(repo, description: "Host open-source project without hassle.")
  ```

  This function validates the given `params` using `changeset/2`.
  """
  @spec update(t, map|keyword) :: {:ok, t} | {:error, Ecto.Changeset.t | :file.posix}
  def update(%__MODULE__{} = repo, params) do
    case update_and_rename(changeset(repo, Map.new(params))) do
      {:ok, %{repo: repo}} ->
        {:ok, repo}
      {:error, :repo, changeset, _changes} ->
        {:error, changeset}
      {:error, :rename, reason, _changes} ->
        {:error, reason}
    end
  end

  @doc """
  Similar to `update/2`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec update!(t, map|keyword) :: t
  def update!(%__MODULE__{} = repo, params) do
    case update(repo, params) do
      {:ok, repo} -> repo
      {:error, %Ecto.Changeset{} = changeset} ->
        raise Ecto.InvalidChangesetError, action: changeset.action, changeset: changeset
      {:error, reason} ->
        raise File.Error, reason: reason, action: "rename directory", path: Path.join(repo.owner.login, repo.name)
    end
  end

  @doc """
  Updates the given `repo` associated issues labels with the given `params`.
  """
  @spec update_issue_labels(t, map|keyword) :: {:ok, t} | {:error, Ecto.Changeset.t}
  def update_issue_labels(repo, params) do
    DB.update(issue_labels_changeset(repo, Map.new(params)))
  end

  @doc """
  Similar to `update_issue_labels/2`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec update_issue_labels!(t, map|keyword) :: t
  def update_issue_labels!(repo, params) do
    DB.update!(issue_labels_changeset(repo, Map.new(params)))
  end

  @doc """
  Deletes the given `repo`.

  Repository associations (maintainers, issues, etc.) and related Git data will automatically be deleted.
  """
  @spec delete(t) :: {:ok, t} | {:error, Ecto.Changeset.t}
  def delete(%__MODULE__{} = repo) do
    case delete_and_cleanup(repo) do
      {:ok, %{repo: repo}} ->
        {:ok, repo}
      {:error, :repo, changeset, _changes} ->
        {:error, changeset}
      {:error, :cleanup, reason, _changes} ->
        {:error, reason}
    end
  end

  @doc """
  Similar to `delete!/1`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec delete!(t) :: t
  def delete!(%__MODULE__{} = repo) do
    case delete(repo) do
      {:ok, repo} -> repo
      {:error, changeset} -> raise Ecto.InvalidChangesetError, action: changeset.action, changeset: changeset
    end
  end

  @doc """
  Returns a repository changeset for the given `params`.
  """
  @spec changeset(t, map) :: Ecto.Changeset.t
  def changeset(%__MODULE__{} = repo, params \\ %{}) do
    repo
    |> cast(params, [:owner_id, :name, :public, :description, :pushed_at])
    |> validate_required([:owner_id, :name])
    |> assoc_constraint(:owner)
    |> validate_format(:name, ~r/^[a-zA-Z0-9_-]+$/)
    |> validate_length(:name, min: 3, max: 80)
    |> validate_exclusion(:name, ["repositories", "settings"])
    |> validate_maintainers()
    |> unique_constraint(:name, name: :repositories_owner_id_name_index)
  end

  @doc """
  Returns a repository changeset for manipulating associated issue labels.
  """
  @spec issue_labels_changeset(t, map) :: Ecto.Changeset.t
  def issue_labels_changeset(%__MODULE__{} = repo, params \\ %{}) do
    repo
    |> struct(issue_labels: Enum.sort_by(repo.issue_labels, &(&1.id)))
    |> cast(params, [])
    |> cast_assoc(:issue_labels, with: &IssueLabel.changeset/2)
  end

  #
  # Protocols
  #

  defimpl GitRekt.GitRepo do
    def get_agent(repo) do
      if agent = RepoPool.lookup(repo) do
        {:ok, agent}
      else
        workdir = RepoStorage.workdir(repo)
        cache = GitAgent.init_cache(workdir, [])
        case RepoPool.start_agent(repo, cache: cache) do
          {:ok, pid} ->
            :ets.give_away(cache, pid, %{})
            {:ok, {pid, cache}}
          {:error, reason} ->
            {:error, reason}
        end
      end
    end
  end

  defimpl GitGud.AuthorizationPolicies do
    import GitGud.RepoQuery, only: [permissions: 2]
    def can?(_repo, _user, action, %{permissions: perms}), do: action in perms
    def can?(repo, user, action, _opts), do: action in permissions(repo, user)
  end

  #
  # Helpers
  #

  defp create_multi(changeset) do
    Multi.new()
    |> Multi.insert(:repo_, changeset)
    |> Multi.run(:repo, &preload_owner/2)
    |> Multi.run(:maintainer, &create_maintainer/2)
    |> Multi.run(:issue_labels, &create_issue_labels/2)
  end

  defp create_and_init_multi(changeset, bare?) do
    changeset
    |> create_multi()
    |> Multi.run(:init, &init(&1, &2, bare?))
  end

  defp preload_owner(db, %{repo_: repo}), do: {:ok, db.preload(repo, :owner)}

  defp create_maintainer(db, %{repo: repo}) do
    changeset = Maintainer.changeset(%Maintainer{}, %{repo_id: repo.id, user_id: repo.owner_id, permission: "admin"})
    db.insert(changeset)
  end

  defp validate_maintainers(changeset) do
    if maintainers = changeset.params["maintainers"],
      do: put_assoc(changeset, :maintainers, maintainers),
    else: changeset
  end

  defp create_issue_labels(db, %{repo: repo}) do
    Enum.reduce_while(@issue_labels, {:ok, []}, fn {name, color}, {:ok, acc} ->
      changeset = IssueLabel.changeset(%IssueLabel{}, %{repo_id: repo.id, name: name, color: color})
      case db.insert(changeset) do
        {:ok, label} -> {:cont, {:ok, [label|acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp update_and_rename(changeset) do
    Multi.new()
    |> Multi.update(:repo, changeset)
    |> Multi.run(:rename, &rename(&1, &2, changeset))
    |> DB.transaction()
  end

  defp delete_and_cleanup(repo) do
    Multi.new()
    |> Multi.delete(:repo, repo)
    |> Multi.run(:cleanup, &cleanup/2)
    |> DB.transaction()
  end

  defp init(_db, %{repo: repo}, bare?), do: RepoStorage.init(repo, bare?)

  defp rename(_db, %{repo: repo}, changeset) do
    unless get_change(changeset, :name),
      do: {:ok, :noop},
    else: RepoStorage.rename(repo, changeset.data)
  end

  defp cleanup(_db, %{repo: repo}), do: RepoStorage.cleanup(repo)
end
