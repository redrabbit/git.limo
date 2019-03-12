defmodule GitGud.GitCommit do
  @moduledoc """
  Defines a Git commit object.
  """

  alias GitRekt.Git

  alias GitGud.Repo

  @enforce_keys [:oid, :repo, :__git__]
  defstruct [:oid, :repo, :__git__]

  @type t :: %__MODULE__{oid: Git.oid, repo: Repo.t, __git__: Git.commit}

  @doc """
  Returns the parents of the given `commit`.
  """
  @spec parents(t) :: {:ok, Stream.t} | {:error, term}
  def parents(%__MODULE__{repo: repo, __git__: commit} = _commit) do
    with {:ok, stream} <- Git.commit_parents(commit),
         {:ok, stream} <- Git.enumerate(stream) do
      try do
        {:ok, Stream.map(stream, &resolve_parent(&1, repo))}
      rescue
        ArgumentError -> {:error, :badarg}
      end
    end
  end

  @doc """
  Returns the first parent of the given `commit`.
  """
  @spec first_parent(t) :: {:ok, t} | {:error, term}
  def first_parent(%__MODULE__{repo: repo, __git__: commit} = _commit) do
    case Git.commit_parents(commit) do
      {:ok, stream} ->
        try do
          {:ok, resolve_first_parent(stream, repo)}
        rescue
          ArgumentError -> {:error, :badarg}
        end
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Returns the author of the given `commit`.
  """
  @spec author(t) :: {:ok, map} | {:error, term}
  def author(%__MODULE__{__git__: commit} = _commit) do
    with {:ok, name, email, time, _offset} <- Git.commit_author(commit), # TODO
         {:ok, datetime} <- DateTime.from_unix(time), do:
      {:ok, %{name: name, email: email, timestamp: datetime}}
  end

  @doc """
  Returns the message of the given `commit`.
  """
  @spec message(t) :: {:ok, binary} | {:error, term}
  def message(%__MODULE__{__git__: commit} = _commit) do
    Git.commit_message(commit)
  end

  @doc """
  Returns the timestamp of the given `commit`.
  """
  @spec timestamp(t) :: {:ok, DateTime.t} | {:error, term}
  def timestamp(%__MODULE__{__git__: commit} = _commit) do
    with {:ok, time, _offset} <- Git.commit_time(commit), # TODO
         {:ok, datetime} <- DateTime.from_unix(time), do:
      {:ok, struct(datetime, [])}
  end

  @doc """
  Returns the GPG signature of the given `commit`.
  """
  @spec gpg_signature(t) :: {:ok, binary} | {:error, term}
  def gpg_signature(%__MODULE__{__git__: commit} = _commit) do
    Git.commit_header(commit, "gpgsig")
  end

  #
  # Protocols
  #

  defimpl Inspect do
    def inspect(commit, _opts) do
      Inspect.Algebra.concat(["#GitCommit<", Git.oid_fmt_short(commit.oid), ">"])
    end
  end

  #
  # Helpers
  #

  defp resolve_parent(nil, _repo), do: raise ArgumentError
  defp resolve_parent({oid, commit}, repo) do
    %__MODULE__{oid: oid, repo: repo, __git__: commit}
  end

  defp resolve_first_parent(stream, repo) do
    stream
    |> Stream.take(1)
    |> Enum.to_list()
    |> List.first()
    |> resolve_parent(repo)
  end
end
