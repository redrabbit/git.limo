defmodule GitGud.GitReference do
  @moduledoc """
  Defines a Git reference object.
  """

  alias GitRekt.Git

  alias GitGud.Repo
  alias GitGud.GitCommit
  alias GitGud.GitTag

  @enforce_keys [:oid, :name, :prefix, :repo, :__git__]
  defstruct [:oid, :name, :prefix, :repo, :__git__]

  @type reference_type :: :branch | :tag

  @type t :: %__MODULE__{oid: Git.oid, name: binary, prefix: binary, repo: Repo.t, __git__: Git.repo}

  @doc """
  Returns the object pointed at by `reference`.
  """
  @spec target(t, Git.obj_type | :undefined) :: {:ok, Repo.git_object} | {:error, term}
  def target(%__MODULE__{name: name, prefix: prefix, repo: repo, __git__: handle} = _reference, type \\ :undefined) do
    case Git.reference_peel(handle, prefix <> name, type) do
      {:ok, :commit, oid, commit} ->
        {:ok, %GitCommit{oid: oid, repo: repo, __git__: commit}}
      {:ok, :tag, oid, tag} ->
        {:ok, %GitTag{oid: oid, name: name, repo: repo, __git__: tag}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Returns the type of the given `reference`.
  """
  @spec type(t) :: {:ok, reference_type} | {:error, term}
  def type(%__MODULE__{prefix: "refs/heads/"} = _reference), do: {:ok, :branch}
  def type(%__MODULE__{prefix: "refs/tags/"} = _reference), do: {:ok, :tag}
  def type(%__MODULE__{} = _reference), do: {:error, :invalid_reference_type}

  #
  # Protocols
  #

  defimpl Inspect do
    def inspect(ref, _opts) do
      Inspect.Algebra.concat(["#GitReference<", ref.name, ">"])
    end
  end
end
