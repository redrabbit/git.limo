defmodule GitRekt do
  @moduledoc false

  alias GitRekt.Git

  defmodule GitCommit do
    @moduledoc """
    Represents a Git commit.
    """
    defstruct [:oid, :__ref__]
    @type t :: %__MODULE__{oid: Git.oid, __ref__: Git.commit}

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

    defimpl String.Chars do
      def to_string(ref), do: Path.join(ref.prefix, ref.name)
    end
  end

  defmodule GitTag do
    @moduledoc """
    Represents a Git tag.
    """
    defstruct [:oid, :name, :__ref__]
    @type t :: %__MODULE__{oid: Git.oid, name: :binary, __ref__: Git.tag}

    defimpl Inspect do
      def inspect(tag, _opts), do: "<GitTag:#{tag.name}>"
    end
  end

  defmodule GitBlob do
    @moduledoc """
    Represents a Git blob.
    """
    defstruct [:oid, :__ref__]
    @type t :: %__MODULE__{oid: Git.oid, __ref__: Git.blob}

    defimpl Inspect do
      def inspect(blob, _opts), do: "<GitBlob:#{Git.oid_fmt_short(blob.oid)}>"
    end
  end

  defmodule GitTree do
    @moduledoc """
    Represents a Git tree.
    """
    defstruct [:oid, :__ref__]
    @type t :: %__MODULE__{oid: Git.oid, __ref__: Git.tree}

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

  defmodule GitIndex do
    @moduledoc """
    Represents a Git index.
    """
    defstruct [:__ref__]
    @type t :: %__MODULE__{__ref__: Git.index}

    defimpl Inspect do
      def inspect(index, _opts), do: "<GitIndex:#{inspect index.__ref__}>"
    end
  end

  defmodule GitIndexEntry do
    @moduledoc """
    Represents a Git index entry.
    """
    @enforce_keys [:mode, :oid, :path, :file_size]
    defstruct [
      ctime: :undefined,
      mtime: :undefined,
      dev: :undefined,
      ino: :undefined,
      mode: nil,
      uid: :undefined,
      gid: :undefined,
      file_size: 0,
      oid: nil,
      flags: :undefined,
      flags_extended: :undefined,
      path: nil
    ]
    @type t :: %__MODULE__{
      ctime: pos_integer | :undefined,
      mtime: pos_integer | :undefined,
      dev: pos_integer | :undefined,
      ino: pos_integer | :undefined,
      mode: pos_integer,
      uid: pos_integer | :undefined,
      gid: pos_integer | :undefined,
      file_size: non_neg_integer,
      oid: binary,
      flags: pos_integer | :undefined,
      flags_extended: pos_integer | :undefined,
      path: binary
    }

    defimpl Inspect do
      def inspect(index_entry, _opts), do: "<GitIndexEntry:#{index_entry.path}>"
    end
  end


  defmodule GitDiff do
    @moduledoc """
    Represents a Git diff.
    """
    defstruct [:__ref__]
    @type t :: %__MODULE__{__ref__: Git.diff}

    defimpl Inspect do
      def inspect(diff, _opts), do: "<GitDiff:#{inspect diff.__ref__}>"
    end
  end

  defmodule GitOdb do
    @moduledoc """
    Represents a Git ODB.
    """
    defstruct [:__ref__]
    @type t :: %__MODULE__{__ref__: Git.odb}

    defimpl Inspect do
      def inspect(odb, _opts), do: "<GitOdb:#{inspect odb.__ref__}>"
    end
  end

  defmodule GitWritePack do
    @moduledoc """
    Represents a Git writepack.
    """
    defstruct [:__ref__]
    @type t :: %__MODULE__{__ref__: Git.odb_writepack}

    defimpl Inspect do
      def inspect(writepack, _opts), do: "<GitWritePack:#{inspect writepack.__ref__}>"
    end
  end

  defmodule GitError do
    @moduledoc false
    defexception [:message, :code]
  end
end
