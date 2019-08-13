defmodule GitRekt do
  @moduledoc false

  alias GitRekt.Git

  defmodule GitCommit do
    @moduledoc """
    Represents a Git commit.
    """
    defstruct [:oid, :commit]
    @type t :: %__MODULE__{oid: Git.oid, commit: Git.commit}
  end

  defmodule GitRef do
    @moduledoc """
    Represents a Git reference.
    """
    defstruct [:oid, :name, :prefix, :type]
    @type t :: %__MODULE__{oid: Git.oid, name: binary, prefix: binary, type: :branch | :tag}
  end

  defmodule GitTag do
    @moduledoc """
    Represents a Git tag.
    """
    defstruct [:oid, :name, :tag]
    @type t :: %__MODULE__{oid: Git.oid, name: :binary, tag: Git.tag}
  end

  defmodule GitBlob do
    @moduledoc """
    Represents a Git blob.
    """
    defstruct [:oid, :blob]
    @type t :: %__MODULE__{oid: Git.oid, blob: Git.blob}
  end

  defmodule GitTree do
    @moduledoc """
    Represents a Git tree.
    """
    defstruct [:oid, :tree]
    @type t :: %__MODULE__{oid: Git.oid, tree: Git.blob}
  end

  defmodule GitTreeEntry do
    @moduledoc """
    Represents a Git tree entry.
    """
    defstruct [:oid, :name, :mode, :type]
    @type t :: %__MODULE__{oid: Git.oid, name: binary, mode: integer, type: :blob | :tree}
  end

  defmodule GitDiff do
    @moduledoc """
    Represents a Git diff.
    """
    defstruct [:diff]
    @type t :: %__MODULE__{diff: Git.diff}
  end
end
