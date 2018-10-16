defmodule GitGud.GitDiff do
  @moduledoc """
  Defines a Git diff.
  """

  alias GitRekt.Git

  alias GitGud.Repo

  @enforce_keys [:repo, :__git__]
  defstruct [:repo, :__git__]

  @type t :: %__MODULE__{repo: Repo.t, __git__: Git.diff}

  @doc """
  Returns the author of the given `tag`.
  """
  @spec format(t) :: {:ok, binary} | {:error, term}
  def format(%__MODULE__{__git__: diff} = _diff) do
    Git.diff_format(diff)
  end
end

