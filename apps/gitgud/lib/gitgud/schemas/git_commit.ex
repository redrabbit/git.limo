defmodule GitGud.GitCommit do
  @moduledoc """
  Git commit schema and helper functions.
  """
  use Ecto.Schema

  alias GitRekt.Git

  alias GitGud.DB
  alias GitGud.Repo

  @primary_key false
  schema "git_commits" do
    belongs_to :repo, Repo, primary_key: true
    field :oid, :binary, primary_key: true
    field :parents, {:array, :binary}
    field :message, :string
    field :author_name, :string
    field :author_email, :string
    field :gpg_signature, :binary
    field :committed_at, :naive_datetime
  end

  @type t :: %__MODULE__{
    repo_id: pos_integer,
    repo: Repo.t,
    oid: Git.oid,
    parents: [Git.oid],
    message: binary,
    author_name: binary,
    author_email: binary,
    gpg_signature: binary,
    committed_at: NaiveDateTime.t
  }

  @doc """
  Returns the number of ancestors for the given `repo_id` and commit `oid`.
  """
  @spec count_ancestors(pos_integer, Git.oid) :: {:ok, pos_integer} | {:error, term}
  def count_ancestors(repo_id, oid) do
    case Ecto.Adapters.SQL.query!(DB, "SELECT COUNT(*) FROM git_commits_dag($1, $2)", [repo_id, oid]) do
      %Postgrex.Result{rows: [[count]]} -> {:ok, count}
    end
  end

  @doc """
  Returns the number of ancestors for the given `commit`.
  """
  @spec count_ancestors(t) :: {:ok, pos_integer} | {:error, term}
  def count_ancestors(%__MODULE__{repo_id: repo_id, oid: oid} = _commit) do
    count_ancestors(repo_id, oid)
  end
end
