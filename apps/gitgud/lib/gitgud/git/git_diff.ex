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
  Returns stats of the given `diff`.
  """
  @spec stats(t) :: {:ok, {non_neg_integer, non_neg_integer, non_neg_integer}} | {:error, term}
  def stats(%__MODULE__{__git__: diff} = _diff) do
    case Git.diff_stats(diff) do
      {:ok, files_changed, insertions, deletions} ->
        {:ok, map_diff_stats({files_changed, insertions, deletions})}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Returns the number of deltas in the given `diff`.
  """
  @spec delta_count(t) :: {:ok, non_neg_integer} | {:error, term}
  def delta_count(%__MODULE__{__git__: diff} = _diff) do
    Git.diff_delta_count(diff)
  end

  @doc """
  Returns a list of deltas for the given `diff`.
  """
  @spec deltas(t) :: {:ok, [{Git.diff_delta, [{Git.diff_hunk, [Git.diff_line]}]}]} | {:error, term}
  def deltas(%__MODULE__{__git__: diff} = _diff) do
    case Git.diff_deltas(diff) do
      {:ok, deltas} -> {:ok, Enum.map(deltas, &map_diff_delta/1)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns a binary represention of the given `diff`.
  """
  @spec format(t, Git.diff_format) :: {:ok, binary} | {:error, term}
  def format(%__MODULE__{__git__: diff} = _diff, diff_format \\ :patch) do
    Git.diff_format(diff, diff_format)
  end

  #
  # Protocols
  #

  defimpl Inspect do
    def inspect(_diff, _opts) do
      Inspect.Algebra.concat(["#GitDiff<", ">"])
    end
  end

  #
  # Helpers
  #

  defp map_diff_stats({files_changed, insertions, deletions}) do
    %{
      files_changed: files_changed,
      insertions: insertions,
      deletions: deletions
    }
  end

  defp map_diff_delta({{old_file, new_file, count, similarity}, hunks}) do
    %{
      old_file: map_diff_file(old_file),
      new_file: map_diff_file(new_file),
      count: count,
      similarity: similarity,
      hunks: Enum.map(hunks, &map_diff_hunk/1)
    }
  end

  defp map_diff_file({oid, path, size, mode}) do
    %{
      oid: oid,
      path: path,
      size: size,
      mode: mode
    }
  end

  defp map_diff_hunk({{header, old_start, old_lines, new_start, new_lines}, lines}) do
    %{
      header: header,
      old_start: old_start,
      old_lines: old_lines,
      new_start: new_start,
      new_lines: new_lines,
      lines: Enum.map(lines, &map_diff_line/1)
    }
  end

  defp map_diff_line({origin, old_line_no, new_line_no, num_lines, content_offset, content}) do
    %{
      origin: <<origin>>,
      old_line_no: old_line_no,
      new_line_no: new_line_no,
      num_lines: num_lines,
      content_offset: content_offset,
      content: content
    }
  end
end

