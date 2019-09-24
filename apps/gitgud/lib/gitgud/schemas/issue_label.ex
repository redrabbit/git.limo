defmodule GitGud.IssueLabel do
  @moduledoc """
  Issue label schema and helper functions.
  """

  use Ecto.Schema

  alias GitGud.Repo

  import Ecto.Changeset

  schema "issue_labels" do
    belongs_to :repo, Repo
    field :name, :string
    field :description, :string
    field :color, :binary
    timestamps()
  end

  @type t :: %__MODULE__{
    id: pos_integer,
    repo_id: pos_integer,
    repo: Repo.t,
    name: binary,
    description: binary,
    color: binary,
    inserted_at: NaiveDateTime.t,
    updated_at: NaiveDateTime.t
  }

  @doc """
  Returns a label changeset for the given `params`.
  """
  @spec changeset(t, map) :: Ecto.Changeset.t
  def changeset(%__MODULE__{} = label, params \\ %{}) do
    label
    |> cast(params, [:repo_id, :name, :description, :color])
    |> validate_required([:repo_id, :name, :color])
    |> assoc_constraint(:repo)
  end
end
