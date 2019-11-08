defmodule GitRekt do
  @moduledoc false

  alias GitRekt.Git

  defmodule GitCommit do
    @moduledoc """
    Represents a Git commit.
    """
    defstruct [:oid, :commit]
    @type t :: %__MODULE__{oid: Git.oid, commit: Git.commit}

    defimpl Inspect do
      def inspect(commit, _opts), do: "<GitCommit:#{Git.oid_fmt_short(commit.oid)}>"
    end
  end

  defmodule GitRef do
    @moduledoc """
    Represents a Git reference.
    """
    defstruct [:oid, :name, :prefix, :type]
    @type t :: %__MODULE__{oid: Git.oid, name: binary, prefix: binary, type: :branch | :tag}

    defimpl Inspect do
      def inspect(ref, _opts), do: "<GitRef:#{ref.prefix}#{ref.name}>"
    end
  end

  defmodule GitTag do
    @moduledoc """
    Represents a Git tag.
    """
    defstruct [:oid, :name, :tag]
    @type t :: %__MODULE__{oid: Git.oid, name: :binary, tag: Git.tag}

    defimpl Inspect do
      def inspect(tag, _opts), do: "<GitTag:#{tag.name}>"
    end
  end

  defmodule GitBlob do
    @moduledoc """
    Represents a Git blob.
    """
    defstruct [:oid, :blob]
    @type t :: %__MODULE__{oid: Git.oid, blob: Git.blob}

    defimpl Inspect do
      def inspect(blob, _opts), do: "<GitBlob:#{Git.oid_fmt_short(blob.oid)}>"
    end
  end

  defmodule GitTree do
    @moduledoc """
    Represents a Git tree.
    """
    defstruct [:oid, :tree]
    @type t :: %__MODULE__{oid: Git.oid, tree: Git.blob}

    defimpl Inspect do
      def inspect(tree, _opts), do: "<GitTree:#{Git.oid_fmt_short(tree.oid)}>"
    end
  end

  defmodule GitTreeEntry do
    @moduledoc """
    Represents a Git tree entry.
    """
    defstruct [:oid, :name, :mode, :type]
    @type t :: %__MODULE__{oid: Git.oid, name: binary, mode: integer, type: :blob | :tree}

    defimpl Inspect do
      def inspect(tree_entry, _opts), do: "<GitTreeEntry:#{tree_entry.name}>"
    end
  end

  defmodule GitDiff do
    @moduledoc """
    Represents a Git diff.
    """
    defstruct [:diff]
    @type t :: %__MODULE__{diff: Git.diff}

    defimpl Inspect do
      def inspect(diff, _opts), do: "<GitDiff:#{inspect diff.diff}>"
    end
  end

  defmodule GitOdb do
    @moduledoc """
    Represents a Git ODB.
    """
    defstruct [:odb]
    @type t :: %__MODULE__{odb: Git.odb}

    defimpl Inspect do
      def inspect(odb, _opts), do: "<GitOdb:#{inspect odb.odb}>"
    end
  end
end
