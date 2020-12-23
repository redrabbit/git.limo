defmodule GitGud.RepoStats do
  @moduledoc """
  Repository stats schema and helper functions.
  """
  use Ecto.Schema

  alias GitGud.Repo

  import Ecto.Changeset

  schema "repository_stats" do
    belongs_to :repo, Repo
    field :refs, :map
    timestamps()
  end

  @type t :: %__MODULE__{
    id: pos_integer,
    repo_id: pos_integer,
    repo: Repo.t,
    refs: map,
    inserted_at: NaiveDateTime.t,
    updated_at: NaiveDateTime.t
  }

  @doc """
  Returns a repository stats changeset for the given `params`.
  """
  @spec changeset(t, map) :: Ecto.Changeset.t
  def changeset(%__MODULE__{} = stats, params \\ %{}) do
    stats
    |> cast(params, [:repo_id, :refs])
    |> validate_required([:repo_id, :refs])
    |> assoc_constraint(:repo)
  end
end
