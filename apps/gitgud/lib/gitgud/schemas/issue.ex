defmodule GitGud.Issue do
  @moduledoc """
  Issue schema and helper functions.
  """

  use Ecto.Schema

  alias Ecto.Multi

  alias GitGud.DB
  alias GitGud.User
  alias GitGud.Repo
  alias GitGud.IssueLabel
  alias GitGud.IssueQuery
  alias GitGud.Comment

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  schema "issues" do
    belongs_to :repo, Repo
    field :number, :integer, read_after_writes: true
    field :title, :string
    field :status, :string, default: "open"
    belongs_to :author, User
    many_to_many :labels, IssueLabel, join_through: "issues_labels", join_keys: [issue_id: :id, label_id: :id]
    many_to_many :comments, Comment, join_through: "issues_comments", join_keys: [thread_id: :id, comment_id: :id]
    field :events, {:array, :map}
    timestamps()
  end

  @type t :: %__MODULE__{
    id: pos_integer,
    repo: Repo.t,
    number: pos_integer,
    title: binary,
    status: binary,
    author_id: pos_integer,
    author: User.t,
    repo_id: pos_integer,
    labels: [IssueLabel.t],
    comments: [Comment.t],
    events: [map],
    inserted_at: NaiveDateTime.t,
    updated_at: NaiveDateTime.t
  }


  @doc """
  Creates a new issue with the given `params`.

  ```elixir
  {:ok, issue} = GitGud.Issue.create(repo_id: repo.id, author_id: user.id, title: "Help me!", comments: [author_id: user.id, body: "I really need help."])
  ```

  This function validates the given `params` using `changeset/2`.
  """
  @spec create(map | keyword) :: {:ok, t} | {:error, Ecto.Changeset.t}
  def create(params) do
    DB.insert(changeset(%__MODULE__{}, map_issue_params(params)))
  end

  @doc """
  Similar to `create/1`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec create!(map | keyword) :: t
  def create!(params) do
    DB.insert!(changeset(%__MODULE__{}, map_issue_params(params)))
  end

  @doc """
  Closes the given `issue`.
  """
  @spec close(t) :: {:ok, t} | {:error, Ecto.Changeset.t}
  def close(issue, opts \\ [])
  def close(%__MODULE__{status: "close"} = issue, _opts), do: {:ok, issue}
  def close(%__MODULE__{} = issue, opts) do
    query = from(i in __MODULE__, where: i.id == ^issue.id, select: i)
    event = Map.merge(Map.new(opts), %{type: "close", timestamp: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)})
    case DB.update_all(query, set: [status: "close", updated_at: event.timestamp], push: [events: event]) do
      {1, [new_issue]} ->
        {:ok, struct(new_issue, Map.take(issue, __schema__(:associations)))}
      {0, nil} ->
        changeset = change(issue, status: "close", events: issue.events ++ [event])
        {:error, %{changeset|action: :update}}
    end
  end

  @doc """
  Similar to `close/1`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec close!(t) :: t
  def close!(%__MODULE__{} = issue, opts \\ []) do
    case close(issue, opts) do
      {:ok, issue} -> issue
      {:error, changeset} -> raise Ecto.InvalidChangesetError, action: changeset.action, changeset: changeset
    end
  end

  @doc """
  Reopens the given `issue`.
  """
  @spec reopen(t) :: {:ok, t} | {:error, term}
  def reopen(issue, opts \\ [])
  def reopen(%__MODULE__{status: "open"} = issue, _opts), do: {:ok, issue}
  def reopen(%__MODULE__{} = issue, opts) do
    query = from(i in __MODULE__, where: i.id == ^issue.id, select: i)
    event = Map.merge(Map.new(opts), %{type: "reopen", timestamp: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)})
    case DB.update_all(query, set: [status: "open", updated_at: event.timestamp], push: [events: event]) do
      {1, [new_issue]} ->
        {:ok, struct(new_issue, Map.take(issue, __schema__(:associations)))}
      {0, nil} ->
        changeset = change(issue, status: "open", events: issue.events ++ [event])
        {:error, %{changeset|action: :update}}
    end
  end

  @doc """
  Similar to `reopen/1`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec reopen!(t) :: t
  def reopen!(%__MODULE__{} = issue, opts \\ []) do
    case reopen(issue, opts) do
      {:ok, issue} -> issue
      {:error, changeset} -> raise Ecto.InvalidChangesetError, action: changeset.action, changeset: changeset
    end
  end

  @doc """
  Updates the title of the given `issue`.
  """
  @spec update_title(t, binary, keyword) :: {:ok, t} | {:error, term}
  def update_title(issue, title, opts \\ [])
  def update_title(%__MODULE__{title: title} = issue, title, _opts), do: {:ok, issue}
  def update_title(%__MODULE__{} = issue, title, opts) do
    query = from(i in __MODULE__, where: i.id == ^issue.id, select: i)
    event = Map.merge(Map.new(Keyword.merge([old_title: issue.title, new_title: title], opts)), %{type: "title_update", timestamp: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)})
    case DB.update_all(query, set: [title: title, updated_at: event.timestamp], push: [events: event]) do
      {1, [new_issue]} ->
        {:ok, struct(new_issue, Map.take(issue, __schema__(:associations)))}
      {0, nil} ->
        changeset = change(issue, title: title, events: issue.events ++ [event])
        {:error, %{changeset|action: :update}}
    end
  end

  @doc """
  Similar to `update_title/2`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec update_title!(t, binary, keyword) :: t
  def update_title!(%__MODULE__{} = issue, title, opts \\ []) do
    case update_title(issue, title, opts) do
      {:ok, issue} -> issue
      {:error, changeset} -> raise Ecto.InvalidChangesetError, action: changeset.action, changeset: changeset
    end
  end

  @doc """
  Updates the labels of the given `issue`.
  """
  @spec update_labels(t, {[pos_integer], [pos_integer]}, keyword) :: {:ok, t} | {:error, term}
  def update_labels(%__MODULE__{} = issue, {labels_push, labels_pull} = _changes, opts \\ []) do
    multi = Multi.new()
    multi =
      unless Enum.empty?(labels_push),
        do: Multi.insert_all(multi, :issue_labels_push, "issues_labels", Enum.map(labels_push, &Map.new(issue_id: issue.id, label_id: &1))),
      else: multi
    multi =
      unless Enum.empty?(labels_pull),
       do: Multi.delete_all(multi, :issue_labels_pull, from(l in "issues_labels", where: l.issue_id == ^issue.id and l.label_id in ^labels_pull)),
     else: multi
    query = from(i in __MODULE__, where: i.id == ^issue.id, select: i)
    event = Map.merge(Map.new(Keyword.merge([push: labels_push, pull: labels_pull, updated_at: NaiveDateTime.utc_now()], opts)), %{type: "labels_update", timestamp: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)})
    multi = Multi.update_all(multi, :issue, query, push: [events: event])
    case DB.transaction(multi) do
      {:ok, %{issue: {1, [issue]}}} ->
        {:ok, DB.preload(issue, :labels)}
      {:error, _operation, reason, _changes} ->
        {:error, reason}
    end
  end

  @doc """
  Similar to `update_labels/2`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec update_labels!(t, {[pos_integer], [pos_integer]}, keyword) :: t
  def update_labels!(%__MODULE__{} = issue, changes, opts \\ []) do
    case update_labels(issue, changes, opts) do
      {:ok, issue} -> issue
      {:error, changeset} -> raise Ecto.InvalidChangesetError, action: changeset.action, changeset: changeset
    end
  end

  @doc """
  Adds a new comment.
  """
  @spec add_comment(t, User.t, binary) :: {:ok, Comment.t} | {:error, term}
  def add_comment(%__MODULE__{} = issue, author, body) do
    case DB.transaction(insert_issue_comment(issue.repo_id, issue.id, author.id, body)) do
      {:ok, %{comment: comment}} ->
        {:ok, struct(comment, issue: issue, author: author)}
      {:error, _operation, reason, _changes} ->
        {:error, reason}
    end
  end

  @doc """
  Returns an issue changeset for the given `params`.
  """
  @spec changeset(t, map) :: Ecto.Changeset.t
  def changeset(%__MODULE__{} = issue, params \\ %{}) do
    issue
    |> cast(params, [:repo_id, :author_id, :title])
    |> cast_assoc(:comments, with: &Comment.changeset/2)
    |> validate_required([:repo_id, :author_id, :title])
    |> put_labels()
    |> assoc_constraint(:repo)
    |> assoc_constraint(:author)
  end

  #
  # Protocols
  #

  defimpl GitGud.AuthorizationPolicies do
    def can?(issue, user, action), do: action in IssueQuery.permissions(issue, user)
  end

  #
  # Helpers
  #

  defp put_labels(changeset) do
    if labels = changeset.params["labels"],
      do: put_assoc(changeset, :labels, labels),
    else: changeset
  end

  defp map_issue_params(issue_params) do
    issue_params =
      Map.new(issue_params, fn
        {key, val} when is_atom(key) -> {key, val}
        {key, val} when is_binary(key) -> {String.to_atom(key), val}
      end)
    Map.update(issue_params, :comments, [], fn comments -> Enum.map(comments, &map_comment_params(issue_params, &1)) end)
  end

  defp map_comment_params(issue_params, {_index, comment_params}) do
    map_comment_params(issue_params, comment_params)
  end

  defp map_comment_params(issue_params, comment_params) do
    comment_params =
      Map.new(comment_params, fn
        {key, val} when is_atom(key) -> {key, val}
        {key, val} when is_binary(key) -> {String.to_atom(key), val}
      end)
    Map.merge(comment_params, %{repo_id: issue_params[:repo_id], thread_table: "issues_comments", author_id: issue_params[:author_id]})
  end

  defp insert_issue_comment(repo_id, issue_id, author_id, body) do
    Multi.new()
    |> Multi.insert(:comment, Comment.changeset(%Comment{}, %{repo_id: repo_id, thread_table: "issues_comments", author_id: author_id, body: body}))
    |> Multi.run(:issue_comment, fn db, %{comment: comment} ->
      case db.insert_all("issues_comments", [%{thread_id: issue_id, comment_id: comment.id}]) do
        {1, val} -> {:ok, val}
      end
    end)
  end
end
