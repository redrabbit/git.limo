defmodule GitGud.Issue do
  @moduledoc """
  Issue schema and helper functions.
  """

  use Ecto.Schema

  alias Ecto.Multi

  alias GitGud.DB
  alias GitGud.Repo
  alias GitGud.User
  alias GitGud.Comment

  import Ecto.Changeset

  schema "issues" do
    belongs_to :repo, Repo
    field :number, :integer, read_after_writes: true
    field :title, :string
    field :status, :string, default: "open"
    belongs_to :author, User
    many_to_many :comments, Comment, join_through: "issues_comments", join_keys: [thread_id: :id, comment_id: :id]
    field :events, {:array, :map}
    timestamps()
  end

  @type t :: %__MODULE__{
    id: pos_integer,
    repo: Repo.t,
    number: pos_integer,
    author_id: pos_integer,
    author: User.t,
    repo_id: pos_integer,
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
  @spec close(t) :: {:ok, t} | {:error, term}
  def close(%__MODULE__{} = issue, opts \\ []) do
    issue
    |> change(status: "close")
    |> put_event(:close, opts)
    |> DB.update()
  end

  @doc """
  Similar to `close/1`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec close!(t) :: t
  def close!(%__MODULE__{} = issue, opts \\ []) do
    issue
    |> change(status: "close")
    |> put_event(:close, opts)
    |> DB.update!()
  end

  @doc """
  Reopens the given `issue`.
  """
  @spec reopen(t) :: {:ok, t} | {:error, term}
  def reopen(%__MODULE__{} = issue, opts \\ []) do
    issue
    |> change(status: "open")
    |> put_event(:reopen, opts)
    |> DB.update()
  end

  @doc """
  Similar to `reopen/1`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec reopen!(t) :: t
  def reopen!(%__MODULE__{} = issue, opts \\ []) do
    issue
    |> change(status: "open")
    |> put_event(:reopen, opts)
    |> DB.update!()
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
  Adds a new `event`.
  """
  @spec add_event(t, map) :: {:ok, t} | {:error, term}
  def add_event(%__MODULE__{} = issue, type, data \\ %{}) do
    issue
    |> change()
    |> put_event(type, data)
    |> DB.update()
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
    |> assoc_constraint(:repo)
    |> assoc_constraint(:author)
  end

  #
  # Protocols
  #

  defimpl GitGud.AuthorizationPolicies do
    alias GitGud.Issue

    # Owner can do everything
    def can?(%Issue{author_id: user_id}, %User{id: user_id}, _action), do: true

    # Everybody can read comments.
    def can?(%Issue{}, _user, :read), do: true

    # Everything-else is forbidden.
    def can?(%Issue{}, _user, _actions), do: false
  end

  #
  # Helpers
  #

  defp put_event(changeset, type, data) do
    event = Map.merge(Map.new(data), %{type: type, timestamp: DateTime.utc_now()})
    changeset
    |> put_change(:events, get_field(changeset, :events, []) ++ [event])
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
