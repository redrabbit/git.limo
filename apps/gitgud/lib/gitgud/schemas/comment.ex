defmodule GitGud.Comment do
  @moduledoc """
  Comment schema and helper functions.

  A `GitGud.Comment` represents a comment in a discussion.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias GitGud.DB
  alias GitGud.User
  alias GitGud.Repo
  alias GitGud.CommentQuery
  alias GitGud.CommentRevision

  schema "comments" do
    belongs_to :repo, Repo
    field :thread_table, :string
    belongs_to :author, User
    belongs_to :parent, __MODULE__
    has_many :children, __MODULE__, foreign_key: :parent_id
    has_many :revisions, CommentRevision
    field :body, :string
    timestamps()
  end

  @type t :: %__MODULE__{
    id: pos_integer,
    repo_id: pos_integer,
    repo: Repo.t,
    thread_table: binary,
    author_id: pos_integer,
    author: User.t,
    parent_id: pos_integer | nil,
    parent: t | nil,
    children: [t],
    revisions: [CommentRevision.t],
    body: binary,
    inserted_at: NaiveDateTime.t,
    updated_at: NaiveDateTime.t
  }

  @doc """
  Updates the given `comment` with the given `params`.

  ```elixir
  {:ok, comment} = GitGud.Comment.update(comment, body: "This is the **new** comment message.")
  ```

  This function validates the given `params` using `changeset/2`.
  """
  @spec update(t, map|keyword) :: {:ok, t} | {:error, Ecto.Changeset.t}
  def update(%__MODULE__{} = comment, params) do
    DB.update(changeset(comment, Map.new(params)))
  end

  @doc """
  Similar to `update/2`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec update!(t, map|keyword) :: t
  def update!(%__MODULE__{} = comment, params) do
    DB.update!(changeset(comment, Map.new(params)))
  end

  @doc """
  Updates the given `comment` with the given `params` and inserts a comment revision as well.

  ```elixir
  {:ok, comment} = GitGud.Comment.update(comment, author, body: "This is the **new** comment message.")
  ```

  This function validates the given `params` using `changeset/2`.
  """
  @spec update(t, User.t, map|keyword) :: {:ok, t} | {:error, Ecto.Changeset.t}
  def update(%__MODULE__{} = comment, author, params) do
    changeset = changeset(comment, Map.new(params))
    if get_change(changeset, :body) do
      old_comment_body = comment.body
      multi =
        Ecto.Multi.new()
        |> Ecto.Multi.update(:comment, changeset)
        |> Ecto.Multi.insert(:revision, fn %{comment: comment} -> Ecto.build_assoc(comment, :revisions, author_id: author.id, body: old_comment_body) end)
      case DB.transaction(multi) do
        {:ok,  %{comment: comment, revision: _revision}} ->
          {:ok, comment}
        {:error, :comment, reason, _changes} ->
          {:error, reason}
        {:error, :comment_revision, reason, _changeset} ->
          {:error, reason}
      end
    else
      DB.update(changeset)
    end
  end

  @doc """
  Similar to `update/3`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec update!(t, User.t, map|keyword) :: t
  def update!(%__MODULE__{} = comment, author, params) do
    case update(comment, author, params) do
      {:ok, comment} ->
        comment
      {:error, changeset} ->
        raise Ecto.InvalidChangesetError, action: changeset.action, changeset: changeset
    end
  end

  @doc """
  Deletes the given `comment`.

  ```elixir
  {:ok, comment} = GitGud.Comment.delete(comment)
  ```
  """
  @spec delete(t) :: {:ok, t} | {:error, Ecto.Changeset.t}
  def delete(%__MODULE__{} = comment) do
    DB.delete(comment)
  end

  @doc """
  Similar to `delete!/1`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec delete!(t) :: t
  def delete!(%__MODULE__{} = comment) do
    DB.delete!(comment)
  end

  @doc """
  Returns a changeset for the given `params`.
  """
  @spec changeset(t, map) :: Ecto.Changeset.t
  def changeset(%__MODULE__{} = comment, params \\ %{}) do
    comment
    |> cast(params, [:parent_id, :body])
    |> validate_required([:body])
    |> assoc_constraint(:parent)
  end

  #
  # Protocols
  #

  defimpl GitGud.AuthorizationPolicies do
    def can?(comment, user, action), do: action in CommentQuery.permissions(comment, user)
  end
end
