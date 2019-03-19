defmodule GitGud.GitCommit.Comment do
  @moduledoc """
  Commit comment schema and helper functions.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  alias GitGud.DB

  alias GitGud.CommentThread
  alias GitGud.Repo

  schema "git_commit_comments" do
    belongs_to :repo, Repo
    belongs_to :thread, CommentThread
    field :oid, :binary
    field :blob_oid, :binary
    field :blob_line, :integer
  end

  @type t :: %__MODULE__{
    id: pos_integer,
    repo_id: pos_integer,
    repo: Repo.t,
    thread_id: pos_integer,
    thread: CommentThread.t,
    oid: GitRekt.Git.oid,
    blob_oid: GitRekt.Git.oid,
    blob_line: pos_integer
  }

  @doc """
  Returns a commit comment changeset for the given `params`.
  """
  @spec changeset(t, map) :: Ecto.Changeset.t
  def changeset(%__MODULE__{} = commit_comment, params \\ %{}) do
    commit_comment
    |> cast(params, [:repo_id, :oid, :blob_oid, :blob_line])
    |> cast_assoc(:thread, required: true, with: &CommentThread.changeset/2)
    |> validate_required([:repo_id, :oid, :blob_oid, :blob_line])
    |> assoc_constraint(:repo)
  end
end
