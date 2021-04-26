defmodule GitGud.Stats do
  @moduledoc """
  Repository stats schema and helper functions.
  """
  use Ecto.Schema

  alias GitGud.Repo

  schema "stats" do
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

end
