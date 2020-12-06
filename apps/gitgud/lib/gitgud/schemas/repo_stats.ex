defmodule GitGud.RepoStats do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :refs, :map
  end

  @type t :: %__MODULE__{refs: map}

  @doc """
  Returns a repository stats changeset for the given `params`.
  """
  @spec changeset(t, map) :: Ecto.Changeset.t
  def changeset(%__MODULE__{} = stats, params \\ %{}) do
    cast(stats, params, [:refs])
  end
end
