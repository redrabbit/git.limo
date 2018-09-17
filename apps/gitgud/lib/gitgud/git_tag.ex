defmodule GitGud.GitTag do
  @moduledoc """
  Defines a Git tag object.
  """

  alias GitRekt.Git

  alias GitGud.User
  alias GitGud.UserQuery

  defstruct [:oid, :name, :__git__]

  @type t :: %__MODULE__{
    __git__: Git.tag,
    oid: Git.oid,
    name: binary
  }

  @doc """
  Returns the author of the given `tag`.
  """
  @spec author(t) :: {:ok, User.t} | {:error, term}
  def author(%__MODULE__{__git__: tag} = _tag) do
    with {:ok, _name, email, _time, _tz} <- Git.tag_author(tag), do:
      {:ok, UserQuery.by_email(email)}
  end

  @doc """
  Returns the message of the given `tag`.
  """
  @spec message(t) :: {:ok, binary} | {:error, term}
  def message(%__MODULE__{__git__: tag} = _tag) do
    Git.tag_message(tag)
  end

end
