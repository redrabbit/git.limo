defmodule GitRekt do
  @moduledoc false

  defmodule GitCommit do
    @moduledoc false
    defstruct [:oid, :commit]
    @type t :: %__MODULE__{oid: Git.oid, commit: Git.commit}
  end

  defmodule GitRef do
    @moduledoc false
    defstruct [:oid, :name, :prefix, :type]
    @type t :: %__MODULE__{oid: Git.oid, name: binary, prefix: binary, type: :branch | :tag}
  end

  defmodule GitTag do
    @moduledoc false
    defstruct [:oid, :name, :tag]
    @type t :: %__MODULE__{oid: Git.oid, name: :binary, tag: Git.tag}
  end

  defmodule GitBlob do
    @moduledoc false
    defstruct [:oid, :blob]
    @type t :: %__MODULE__{oid: Git.oid, blob: Git.blob}
  end

  defmodule GitTree do
    @moduledoc false
    defstruct [:oid, :tree]
    @type t :: %__MODULE__{oid: Git.oid, tree: Git.blob}
  end

  defmodule GitTreeEntry do
    @moduledoc false
    defstruct [:oid, :name, :mode, :type]
    @type t :: %__MODULE__{oid: Git.oid, name: binary, mode: integer, type: :blob | :tree}
  end

  defmodule GitDiff do
    @moduledoc false
    defstruct [:diff]
    @type t :: %__MODULE__{diff: Git.diff}
  end
end
