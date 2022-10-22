defmodule GitRekt.Git do
  @moduledoc ~S"""
  Erlang NIF that exposes a subset of *libgit2*'s library functions.

  Most functions available in this module are implemented in C for performance reasons.
  These functions are compiled into a dynamic loadable, shared library. They are called like any other Elixir functions.

  > As a NIF library is dynamically linked into the emulator process, this is the fastest way of calling C-code from Erlang (alongside port drivers). Calling NIFs requires no context switches. But it is also the least safe, because a crash in a NIF brings the emulator down too.
  >
  > [Erlang documentation - NIFs](http://erlang.org/doc/tutorial/nif.html)

  ## Example

  Let's start with a basic code example showing the last commit author and message:

  ```elixir
  alias GitRekt.Git

  # load repository
  {:ok, repo} = Git.repository_open("/tmp/my-repo.git")

  # fetch commit pointed by master
  {:ok, :commit, _oid, commit} = Git.reference_peel(repo, "refs/heads/master")

  # fetch commit author & message
  {:ok, name, email, time, _offset} = Git.commit_author(commit)
  {:ok, message} = Git.commit_message(commit)

  IO.puts "Last commit by #{name} <#{email}>:"
  IO.puts message
  ```

  First we open our repository using `repository_open/1`, passing the path of the Git repository.  We can fetch
  a commit by passing the exact reference path to `reference_peel/2`. In our example, this allows us to retrieve
  the commit *refs/heads/master* is pointing to.

  This is one of many ways to fetch a given revision, `reference_lookup/2` and `reference_glob/2` offer similar
  functionalities. There are other related functions such as `revparse_single/2` and `revparse_ext/2` which
  provide support for parsing [revspecs](https://git-scm.com/book/en/v2/Git-Tools-Revision-Selection).

  ## Walk commit history

  In order to walk the commit ancestry chain, we have a few functions at our disposal: `revwalk_new/1`,
  `revwalk_push/2`, `revwalk_next/1`, `revwalk_reset/1`, etc.

  ```
  # create revision walk iterator
  {:ok, revwalk} = Git.revwalk_new(repo)

  # set root commit for traversal
   :ok = Git.revwalk_push(walk, commit_oid)

  # create (lazy) stream of ancestors from iterator
  {:ok, stream} = Git.revwalk_stream(walk)

  for ancestor_oid <- stream do
    # fetch commit object
    {:ok, :commit, commit} = Git.object_lookup(ancestor_oid)

    # fetch commit message
    {:ok, message} = Git.commit_message(commit)

    IO.puts "#{Git.oid_fmt_short(ancestor_oid)} - #{message}"
  end
  ```

  In this example `revwalk_new/1` returns a `t:revwalk/0`, a mutable *C-like* iteratable object. This means
  that `revwalk_push/2` mutates the *revwalk* object instead of returning a new object.

  The `revwalk_stream/1` function converts the *revwalk* iterator to a `t:Enumerable.t/0` we can then use to walk
  the commit ancestry chain.

  When iterating through a commit's history, `revwalk_sorting/2` and `revwalk_simplify_first_parent/1` provide
  conveniences for sorting and filtering while `revwalk_push/3` can be used to hide specific commits.

  ## Retrieve blobs & trees

  In order to access the actual files and directories of a repository, we have to retrieve the Git blob and tree
  objects of a given revision. Here we simply list files and folders at the root directory:

  ```elixir
  # fetch commit tree
  {:ok, tree} = Git.commit_tree(commit)

  # fetch tree entries at /
  {:ok, tree_entries} = Git.tree_entries(tree)

  for {mode, type, oid, name} <- tree_entries do
    # fetch tree entry object by oid (blob or tree)
    case Git.object_lookup(repo, oid) do
      {:ok, :blob, blob} ->
        # fetch blob size
        {:ok, blob_size} = Git.blob_size(blob)
        IO.puts "#{name} -- #{blob_size} bytes"
      {:ok, :tree, tree} ->
        # fetch number of sub entries
        {:ok, count} <- Git.tree_count(tree)
        IO.puts "#{name}/ -- #{count} items"
    end
  end
  ```

  Note that `tree_entries/1` and `tree_nth/2` return a tuple in the form of `{mode, type, oid, name}`. In order to
  call blob and tree specific functions such as `blob_size/1`  and `tree_count/1`, we still need to lookup the Git object using `object_lookup/2`.

  Here's an other example showing a convenient way to retrieve a tree entry by path:

  ```elixir
  # fetch commit tree
  {:ok, tree} = Git.commit_tree(commit)

  # fetch blob by path
  {:ok, mode, :blob, oid, name} Git.tree_bypath(tree, "README.md")

  # fetch blob object by oid
  {:ok, :blob, blob} = Git.object_lookup(repo, oid)

  # fetch blob content
  {:ok, data} = Git.blob_content(blob)

  IO.binwrite data
  ```

  ## Compare revisions

  Now that we know how to access files and directories, it might be interesting to determine the changes
  between two versions. In order to do so, we need to compare two tree objects from different revisions:

  ```elixir
  # fetch tree for tag v1.2
  {:ok, v1_2, :commit, _oid} = Git.revparse_single(repo, "v1.2")
  {:ok, v1_2_tree} = Git.commit_tree(v1_2)

  # fetch tree for tag v1.3
  {:ok, v1_3, :commit, _oid} = Git.revparse_single(repo, "v1.3")
  {:ok, v1_3_tree} = Git.commit_tree(v1_3)

  # fetch diff between v1.2 and v1.3
  {:ok, diff} = Git.diff_tree(repo, v1_2_tree, v1_3_tree)

  # format diff to string
  {:ok, patch} = Git.diff_format(diff, :patch)

  IO.puts patch
  ```

  Note that `diff_tree/4` takes options such as `:pathspec` allowing to filter changes based on a given path.

  For example, we might want to see the different between two revision for a specific file. In this case we
  could modify the above example as follow to print changes affecting *README.md*:

  ```elixir
  # fetch diff between v1.2 and v1.3 for README.md
  {:ok, diff} = Git.diff_tree(repo, v1_2_tree, v1_3_tree, pathspec: "README.md")

  # format diff to string
  {:ok, patch} = Git.diff_format(diff, :patch)

  IO.puts patch
  ```

  ## Commit changes

  Committing changes to a repository is done in a serie of distinct steps.

  First, we add a new blob object to the repository:

  ```
  # Blob content
  blob_content = "Hello world\n"

  # Open repository ODB
  {:ok, odb} = Git.repository_get_odb(repo)

  # Write new blob object
  {:ok, blob_oid} = Git.odb_write(odb, blob_content, :blob)
  ```

  We create an in-memory index to stage our modifications (an index is a list of path names, each with
  permissions and the SHA1 of a blob object). In order to create a new tree object reflecting our changes, we
  have to assign our new blob object at a given path in the index and write the index back to the repository:

  ```
  # Blob path
  blob_path = "README"

  # Create new index
  {:ok, index} = Git.index_new()

  # Read last commit tree into index
  :ok = Git.index_read_tree(index, tree)

  # Add newly added blob object to index
  :ok = Git.index_add(repo, index, blob_oid, blob_path, byte_size(blob_content), 0o100644)

  # Write index
  {:ok, tree_oid} = Git.index_write_tree(index)
  ```

  The repository now contains a new blob object and a new tree object reflecting our changes. We now have all the
  ingredients for creating a commit and update the *master* branch accordingly:

  ```
  # Commit message
  commit_message = "Add README"

  # Fetch repository default signature for authoring and committing
  {:ok, sig_name, sig_email, sig_ts, sig_tz} = Git.signature_default(repo)
  commit_author = {sig_name, sig_email, sig_ts, sig_tz}
  commit_committer = commit_author

  # Fetch reference to update
  {:ok, :commit, parent_oid, _parent} = Git.reference_peel(repo, "refs/heads/master")

  # Create new commit
  {:ok, commit_oid} = Git.commit_create(repo, :undefined, commit_author, commit_committer, :undefined, commit_message, tree_oid, [parent_oid])

  # Update master branch to new commit
  :ok = Git.reference_create(repo, "refs/heads/master", :oid, commit_oid)

  IO.puts "File #{blob_path} added in commit #{Git.oid_fmt(commit_oid)}."
  ```

  We have created a commit pointing at the new tree object. The commit refers the newly created tree and requires two
  user signatures (author and committer), a commit message and the commit ancestor(s).

  Finally we have updated the *master* branch to point at our new commit.

  ## Thread safety

  Accessing a `t:repo/0` or any NIF allocated pointer (`t:blob/0`, `t:commit/0`, `t:config/0`, etc.) from multiple
  processes simultaneously is not safe. These pointers should never be shared across processes.

  In order to access a repository in a concurrent manner, each process has to initialize it's own repository
  resource using `repository_open/1`. Alternatively, the `GitRekt.GitAgent` module provides a similar API but
  can use a dedicated process, so that its access can be serialized.
  """

  alias GitRekt.GitStream

  @type repo                    :: reference

  @type oid                     :: binary
  @type signature               :: {binary, binary, non_neg_integer, non_neg_integer}

  @type odb                     :: reference
  @type odb_type                :: atom

  @type odb_writepack           :: reference
  @type odb_writepack_progress  :: map

  @type ref_iter                :: reference
  @type ref_type                :: :oid | :symbolic

  @type config                  :: reference
  @type blob                    :: reference
  @type commit                  :: reference
  @type tag                     :: reference

  @type obj                     :: blob | commit | tree | tag
  @type obj_type                :: :blob | :commit | :tree | :tag

  @type reflog_entry            :: {
    binary,
    binary,
    non_neg_integer,
    non_neg_integer,
    oid,
    oid,
    binary
  }

  @type tree                    :: reference
  @type tree_entry              :: {integer, :blob | :tree, oid, binary}

  @type diff                    :: reference
  @type diff_format             :: :patch | :patch_header | :raw | :name_only | :name_status
  @type diff_delta              :: {diff_file, diff_file, non_neg_integer, non_neg_integer}
  @type diff_file               :: {oid, binary, integer, non_neg_integer}
  @type diff_hunk               :: {binary, integer, integer, integer, integer}
  @type diff_line               :: {char, integer, integer, integer, integer, binary}

  @type index                   :: reference
  @type index_entry             :: {
    integer,
    integer,
    non_neg_integer,
    non_neg_integer,
    non_neg_integer,
    non_neg_integer,
    non_neg_integer,
    integer,
    binary,
    non_neg_integer,
    non_neg_integer,
    binary
  }

  @type indexer_progress        :: reference

  @type revwalk                 :: reference
  @type revwalk_sort            :: :sort_topo | :sort_time | :sort_reverse

  @type pack                    :: reference

  @type worktree                :: reference

  @on_load :load_nif

  @doc false
  def load_nif do
    case :erlang.load_nif(nif_path(), 0) do
      :ok -> :ok
      {:error, {:load_failed, error}} -> raise RuntimeError, message: error
    end
  end

  @doc """
  Returns a repository handle for the `path`.
  """
  @spec repository_open(Path.t) :: {:ok, repo} | {:error, term}
  def repository_open(_path) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns `true` if `repo` is bare; elsewise returns `false`.
  """
  @spec repository_bare?(repo) :: boolean
  def repository_bare?(_repo) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns `true` if `repo` is empty; elsewise returns `false`.
  """
  @spec repository_empty?(repo) :: boolean
  def repository_empty?(_repo) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns the absolute path for the given `repo`.
  """
  @spec repository_get_path(repo) :: Path.t
  def repository_get_path(_repo) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns the normalized path to the working directory for the given `repo`.
  """
  @spec repository_get_workdir(repo) :: Path.t
  def repository_get_workdir(_repo) do
      raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns the ODB for the given `repository`.
  """
  @spec repository_get_odb(repo) :: {:ok, odb} | {:error, term}
  def repository_get_odb(_repo) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns the index for the given `repository`.
  """
  @spec repository_get_index(repo) :: {:ok, index} | {:error, term}
  def repository_get_index(_repo) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns the config for the given `repo`.
  """
  @spec repository_get_config(repo) :: {:ok, config} | {:error, term}
  def repository_get_config(_repo) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Make the `repo` HEAD point to the specified reference.
  """
  @spec repository_set_head(repo, binary) :: :ok | {:error, term}
  def repository_set_head(_repo, _refname) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Initializes a new repository at the given `path`.
  """
  @spec repository_init(Path.t, boolean) :: {:ok, repo} | {:error, term}
  def repository_init(_path, _bare \\ false) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Looks for a repository and returns its path.
  """
  @spec repository_discover(Path.t) :: {:ok, Path.t} | {:error, term}
  def repository_discover(_path) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns all references for the given `repo`.
  """
  @spec reference_list(repo) :: {:ok, [binary]} | {:error, term}
  def reference_list(_repo) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Recursively peels the given reference `name` until an object of type `type` is found.
  """
  @spec reference_peel(repo, binary, obj_type | :undefined) :: {:ok, obj_type, oid, obj} | {:error, term}
  def reference_peel(_repo, _name, _type \\ :undefined) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Creates a new reference name which points to an object or to an other reference.
  """
  @spec reference_create(repo, binary, ref_type, binary | oid, boolean) :: :ok | {:error, term}
  def reference_create(_repo, _name, _type, _target, _force \\ false) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Deletes an existing reference.
  """
  @spec reference_delete(repo, binary) :: :ok | {:error, term}
  def reference_delete(_repo, _name) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Looks for a reference by `name` and returns its id.
  """
  @spec reference_to_id(repo, binary) :: {:ok, oid} | {:error, term}
  def reference_to_id(_repo, _name) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Similar to `reference_list/1` but allows glob patterns.
  """
  @spec reference_glob(repo, binary) :: {:ok, [binary]} | {:error, term}
  def reference_glob(_repo, _glob) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Looks for a reference by `name`.
  """
  @spec reference_lookup(repo, binary) :: {:ok, binary, ref_type, binary} | {:error, term}
  def reference_lookup(_repo, _name) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns an iterator for the references that match the specific `glob` pattern.
  """
  @spec reference_iterator(repo, binary | :undefined) :: {:ok, ref_iter} | {:error, term}
  def reference_iterator(_repo, _glob \\ :undefined) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns the next reference.
  """
  @spec reference_next(ref_iter) :: {:ok, binary, binary, ref_type, binary} | {:error, term}
  def reference_next(_iter) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns a stream for the references that match the specific `glob` pattern.
  """
  @spec reference_stream(repo, binary | :undefined) :: {:ok, Enumerable.t} | {:error, term}
  def reference_stream(repo, glob \\ :undefined) do
    case reference_iterator(repo, glob) do
      {:ok, iter} -> {:ok, GitStream.new(iter, &reference_stream_next/1)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Resolves a symbolic reference to a direct reference.
  """
  @spec reference_resolve(repo, binary) :: {:ok, binary, binary, oid} | {:error, term}
  def reference_resolve(_repo, _name) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Looks for a reference by DWIMing its `short_name`.
  """
  @spec reference_dwim(repo, binary) :: {:ok, binary, ref_type, binary} | {:error, term}
  def reference_dwim(_repo, _short_name) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns `true` if a reflog exists for the given reference `name`.
  """
  @spec reference_log?(repo, binary) :: {:ok, boolean} | {:error, term}
  def reference_log?(_repo, _name) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Reads the number of entry for the given reflog `name`.
  """
  @spec reflog_count(repo, binary) :: {:ok, pos_integer} | {:error, term}
  def reflog_count(_repo, _name) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Reads the reflog for the given reference `name`.
  """
  @spec reflog_read(repo, binary) :: {:ok, [reflog_entry]} | {:error, term}
  def reflog_read(_repo, _name) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Deletes the reflog for the given reference `name`.
  """
  @spec reflog_delete(repo, binary) :: :ok | {:error, term}
  def reflog_delete(_repo, _name) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns the number of unique commits between two commit objects.
  """
  @spec graph_ahead_behind(repo, oid, oid) :: {:ok, non_neg_integer, non_neg_integer}
  def graph_ahead_behind(_repo, _local, _upstream) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns the OID of an object `type` and raw `data`.

  The resulting SHA-1 OID will be the identifier for the data buffer as if the data buffer it were to written to the ODB.
  """
  @spec odb_object_hash(obj_type, binary) :: {:ok, oid} | {:error, term}
  def odb_object_hash(_type, _data) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns `true` if the given `oid` exists in `odb`; elsewise returns `false`.
  """
  @spec odb_object_exists?(odb, oid) :: boolean
  def odb_object_exists?(_odb, _oid) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Return the uncompressed, raw data of an ODB object.
  """
  @spec odb_read(odb, oid) :: {:ok, obj_type, binary}
  def odb_read(_odb, _oid) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Writes the given object `data` with the given `type` into the `odb`.
  """
  @spec odb_write(odb, binary, odb_type) :: {:ok, oid} | {:error, term}
  def odb_write(_odb, _data, _type) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Writes the given PACK `data` into the `odb`.
  """
  @spec odb_write_pack(odb, binary) :: :ok | {:error, term}
  def odb_write_pack(_odb, _data) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns an ODB write-pack for the given `odb`.
  """
  @spec odb_get_writepack(odb) :: {:ok, odb_writepack} | {:error, term}
  def odb_get_writepack(_odb) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Appends the given `data` to the `odb_writepack`.
  """
  @spec odb_writepack_append(odb_writepack, binary, indexer_progress) :: :ok | {:error, term}
  def odb_writepack_append(_odb_writepack, _data, _progress) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Commits the written data to the `odb_writepack`.
  """
  @spec odb_writepack_commit(odb_writepack, indexer_progress) :: :ok | {:error, term}
  def odb_writepack_commit(_odb_writepack, _progress) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns the SHA `hash` for the given `oid`.
  """
  @spec oid_fmt(oid) :: binary
  def oid_fmt(_oid) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns the abbreviated SHA `hash` for the given `oid`.
  """
  @spec oid_fmt_short(oid) :: binary
  def oid_fmt_short(oid), do: String.slice(oid_fmt(oid), 0..6)

  @doc """
  Returns the OID for the given SHA `hash`.
  """
  @spec oid_parse(binary) :: oid
  def oid_parse(_hash) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns the repository that owns the given `obj`.
  """
  @spec object_repository(obj) :: {:ok, repo} | {:error, term}
  def object_repository(_obj) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Looks for an object with the given `oid`.
  """
  @spec object_lookup(repo, oid) :: {:ok, obj_type, obj} | {:error, term}
  def object_lookup(_repo, _oid) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns the OID for the given `obj`.
  """
  @spec object_id(obj) :: {:ok, oid} | {:error, term}
  def object_id(_obj) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Inflates the given `data` with *zlib*.
  """
  @spec object_zlib_inflate(binary, pos_integer) :: {:ok, iodata, non_neg_integer} | {:error, term}
  def object_zlib_inflate(_data, _buffer_size \\ 16_384) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns parent commits of the given `commit`.
  """
  @spec commit_parents(commit) :: {:ok, Enumerable.t} | {:error, term}
  def commit_parents(commit) do
    case commit_parent_count(commit) do
      {:ok, count} ->
        {:ok, GitStream.new(commit, {commit, 0, count}, &commit_parent_stream_next/1)}
    end
  end

  @doc """
  Looks for a parent commit of the given `commit` by its `index`.
  """
  @spec commit_parent(commit, non_neg_integer) :: {:ok, oid, commit} | {:error, term}
  def commit_parent(_commit, _index) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns the number of parents for the given `commit`.
  """
  @spec commit_parent_count(commit) :: oid
  def commit_parent_count(_commit) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns the tree id for the given `commit`.
  """
  @spec commit_tree_id(commit) :: oid
  def commit_tree_id(_commit) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns the tree for the given `commit`.
  """
  @spec commit_tree(commit) :: {:ok, oid, tree} | {:error, term}
  def commit_tree(_commit) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Creates a new commit with the given params.
  """
  @spec commit_create(repo, binary | :undefined, signature, signature, binary | :undefined, binary, oid, [binary]) :: {:ok, oid} | {:error, term}
  def commit_create(_repo, _ref, _author, _commiter, _encoding, _message, _tree, _parents) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns the message for the given `commit`.
  """
  @spec commit_message(commit) :: {:ok, binary} | {:error, term}
  def commit_message(_commit) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns the author of the given `commit`.
  """
  @spec commit_author(commit) :: {:ok, binary, binary, non_neg_integer, non_neg_integer} | {:error, term}
  def commit_author(_commit) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns the committer of the given `commit`.
  """
  @spec commit_committer(commit) :: {:ok, binary, binary, non_neg_integer, non_neg_integer} | {:error, term}
  def commit_committer(_commit) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns the time of the given `commit`.
  """
  @spec commit_time(commit) :: {:ok, non_neg_integer, non_neg_integer} | {:error, term}
  def commit_time(_commit) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns the full raw header of the given `commit`.
  """
  @spec commit_raw_header(commit) :: {:ok, binary} | {:error, term}
  def commit_raw_header(_commit) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns an arbitrary header `field` of the given `commit`.
  """
  @spec commit_header(commit, binary) :: {:ok, binary} | {:error, term}
  def commit_header(_commit, _field) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Retrieves a tree entry owned by the given `tree`, given its id.
  """
  @spec tree_byid(tree, oid) :: {:ok, integer, atom, binary, binary} | {:error, term}
  def tree_byid(_tree, _oid) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Retrieves a tree entry contained in the given `tree` or in any of its subtrees, given its relative path.
  """
  @spec tree_bypath(tree, Path.t) :: {:ok, integer, atom, binary, binary} | {:error, term}
  def tree_bypath(_tree, _path) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns the number of entries listed in the given `tree`.
  """
  @spec tree_count(tree) :: {:ok, non_neg_integer} | {:error, term}
  def tree_count(_tree) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Looks for a tree entry by its position in the given `tree`.
  """
  @spec tree_nth(tree, non_neg_integer) :: {:ok, integer, atom, binary, binary} | {:error, term}
  def tree_nth(_tree, _nth) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns all entries in the given `tree`.
  """
  @spec tree_entries(tree) :: {:ok, Enumerable.t} | {:error, term}
  def tree_entries(tree) do
    {:ok, GitStream.new(tree, {tree, 0}, &tree_stream_next/1)}
  end

  @doc """
  Returns the size in bytes of the given `blob`.
  """
  @spec blob_size(blob) :: {:ok, integer} | {:error, term}
  def blob_size(_blob) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns the raw content of the given `blob`.
  """
  @spec blob_content(blob) :: {:ok, binary} | {:error, term}
  def blob_content(_blob) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns all tags for the given `repo`.
  """
  @spec tag_list(repo) :: {:ok, [binary]} | {:error, term}
  def tag_list(_repo) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Recursively peels the given `tag` until a non tag object is found.
  """
  @spec tag_peel(tag) :: {:ok, obj_type, oid, obj} | {:error, term}
  def tag_peel(_tag) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns the name of the given `tag`.
  """
  @spec tag_name(tag) :: {:ok, binary} | {:error, term}
  def tag_name(_tag) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns the message of the given `tag`.
  """
  @spec tag_message(tag) :: {:ok, binary} | {:error, term}
  def tag_message(_tag) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns the author of the given `tag`.
  """
  @spec tag_author(tag) :: {:ok, binary, binary, non_neg_integer, non_neg_integer} | {:error, term}
  def tag_author(_tag) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns the *libgit2* library version.
  """
  @spec library_version() :: {integer, integer, integer}
  def library_version() do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Creates a new revision walk object for the given `repo`.
  """
  @spec revwalk_new(repo) :: {:ok, reference} | {:error, term}
  def revwalk_new(_repo) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Adds a new root for the traversal.
  """
  @spec revwalk_push(revwalk, oid, boolean) :: :ok | {:error, term}
  def revwalk_push(_walk, _oid, _hide \\ false) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns the next commit from the given revision `walk`.
  """
  @spec revwalk_next(revwalk) :: {:ok, oid} | {:error, term}
  def revwalk_next(_walk) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Changes the sorting mode when iterating through the repository's contents.
  """
  @spec revwalk_sorting(revwalk, [revwalk_sort]) :: :ok | {:error, term}
  def revwalk_sorting(_walk, _sort_mode) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Simplifies the history by first-parent.
  """
  @spec revwalk_simplify_first_parent(revwalk) :: :ok | {:error, term}
  def revwalk_simplify_first_parent(_walk) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Resets the revision `walk` for reuse.
  """
  @spec revwalk_reset(revwalk) :: revwalk
  def revwalk_reset(_walk) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns a stream for the given revision `walk`.
  """
  @spec revwalk_stream(revwalk) :: {:ok, Enumerable.t} | {:error, term}
  def revwalk_stream(walk) do
    {:ok, GitStream.new(walk, &revwalk_stream_next/1)}
  end

  @doc """
  Returns the repository on which the given `walker` is operating.
  """
  @spec revwalk_repository(revwalk) :: {:ok, repo} | {:error, term}
  def revwalk_repository(_walk) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns `true` if `tree` matches the given `pathspec`; otherwise returns `false`.
  """
  @spec pathspec_match_tree(tree, [binary]) :: {:ok, boolean} | {:error, term}
  def pathspec_match_tree(_tree, _pathspec) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns a *PACK* file for the given `walk`.
  """
  @spec revwalk_pack(revwalk) :: {:ok, binary} | {:error, term}
  def revwalk_pack(_walk) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns a diff with the difference between two tree objects.
  """
  @spec diff_tree(repo, tree, tree) :: {:ok, diff} | {:error, term}
  def diff_tree(_repo, _old_tree, _new_tree, _opts \\ []) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns stats for the given `diff`.
  """
  @spec diff_stats(diff) :: {:ok, non_neg_integer, non_neg_integer, non_neg_integer} | {:error, term}
  def diff_stats(_diff) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns the number of deltas in the given `diff`.
  """
  @spec diff_delta_count(diff) :: {:ok, non_neg_integer} | {:error, term}
  def diff_delta_count(_diff) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns a list of deltas for the given `diff`.
  """
  @spec diff_deltas(diff) :: {:ok, [{diff_delta, [{diff_hunk, [diff_line]}]}]} | {:error, term}
  def diff_deltas(_diff) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns a binary represention of the given `diff`.
  """
  @spec diff_format(diff, diff_format) :: {:ok, binary} | {:error, term}
  def diff_format(_diff, _format \\ :patch) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Creates an new in-memory index object.
  """
  @spec index_new() :: {:ok, index} | {:error, term}
  def index_new do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Writes the given `index` from memory back to disk using an atomic file lock.
  """
  @spec index_write(index) :: :ok | {:error, term}
  def index_write(_index) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Writes the given `index` as a tree.
  """
  @spec index_write_tree(index) :: {:ok, oid} | {:error, term}
  def index_write_tree(_index) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Writes the given `index` as a tree.
  """
  @spec index_write_tree(index, repo) :: {:ok, oid} | {:error, term}
  def index_write_tree(_index, _repo) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Reads the given `tree` into the given `index` file with stats.
  """
  @spec index_read_tree(index, tree) :: :ok | {:error, term}
  def index_read_tree(_index, _tree) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns the number of entries in the given `index`.
  """
  @spec index_count(index) :: non_neg_integer()
  def index_count(_index) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Looks for an entry by its position in the given `index`.
  """
  @spec index_nth(index, non_neg_integer) ::
  {:ok, integer,
        integer,
        non_neg_integer,
        non_neg_integer,
        non_neg_integer,
        non_neg_integer,
        non_neg_integer,
        integer,
        binary,
        non_neg_integer,
        non_neg_integer,
        binary} |
  {:error, term}

  def index_nth(_index, _nth) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Retrieves an entry contained in the `index` given its relative path.
  """
  @spec index_bypath(index, Path.t, non_neg_integer) ::
  {:ok, integer,
        integer,
        non_neg_integer,
        non_neg_integer,
        non_neg_integer,
        non_neg_integer,
        non_neg_integer,
        integer,
        binary,
        non_neg_integer,
        non_neg_integer,
        binary} |
  {:error, term}
  def index_bypath(_index, _path, _stage) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Adds or updates the given `entry`.
  """
  @spec index_add(index, index_entry) :: :ok | {:error, term}
  def index_add(_index, _entry) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Removes an entry from the given `index`.
  """
  @spec index_remove(index, Path.t, non_neg_integer) :: :ok | {:error, term}
  def index_remove(_index, _path, _stage \\ 0) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Removes all entries from the given `index` under a given directory.
  """
  @spec index_remove_dir(index, Path.t, non_neg_integer) :: :ok | {:error, term}
  def index_remove_dir(_index, _path, _stage \\ 0) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Clears the contents (all the entries) of the given `index`.
  """
  @spec index_clear(index) :: :ok | {:error, term}
  def index_clear(_index) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns the default signature for the given `repo`.
  """
  @spec signature_default(repo) :: {:ok, binary, binary, non_neg_integer, non_neg_integer} | {:error, term}
  def signature_default(_repo) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Creates a new signature with the given `name` and `email`.
  """
  @spec signature_new(binary, binary) :: {:ok, binary, binary}
  def signature_new(_name, _email) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Creates a new signature with the given `name`, `email` and `time`.
  """
  @spec signature_new(binary, binary, non_neg_integer) :: {:ok, binary, binary, non_neg_integer, non_neg_integer} | {:error, term}
  def signature_new(_name, _email, _time) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Finds a single object, as specified by the given `revision`.
  """
  @spec revparse_single(repo, binary) :: {:ok, obj, obj_type, oid} | {:error, term}
  def revparse_single(_repo, _revision) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Finds a single object and intermediate reference, as specified by the given `revision`.
  """
  @spec revparse_ext(repo, binary) :: {:ok, obj, obj_type, oid, binary | nil} | {:error, term}
  def revparse_ext(_repo, _revision) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Sets the `config` entry with the given `name` to `val`.
  """
  @spec config_set_bool(config, binary, boolean) :: :ok | {:error, term}
  def config_set_bool(_config, _name, _val) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns the value of the `config` entry with the given `name`.
  """
  @spec config_get_bool(config, binary) :: {:ok, boolean} | {:error, term}
  def config_get_bool(_config, _name) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Sets the `config` entry with the given `name` to `val`.
  """
  @spec config_set_string(config, binary, binary) :: :ok | {:error, term}
  def config_set_string(_config, _name, _val) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns the value of the `config` entry with the given `name`.
  """
  @spec config_get_string(config, binary) :: {:ok, binary} | {:error, term}
  def config_get_string(_config, _name) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns a config handle for the given `path`.
  """
  @spec config_open(binary) :: {:ok, config} | {:error, term}
  def config_open(_path) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Creates a new *PACK* object for the given `repo`.
  """
  @spec pack_new(repo) :: {:ok, pack} | {:error, term}
  def pack_new(_repo) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Inserts `commit` as well as the completed referenced tree.
  """
  @spec pack_insert_commit(pack, oid) :: :ok | {:error, term}
  def pack_insert_commit(_pack, _oid) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end


  @doc """
  Inserts objects as given by the `walk`.
  """
  @spec pack_insert_walk(pack, revwalk) :: :ok | {:error, term}
  def pack_insert_walk(_pack, _walk) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Returns a *PACK* file for the given `pack`.
  """
  @spec pack_data(pack) :: {:ok, binary} | {:error, term}
  def pack_data(_pack) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Adds a new working tree for the given `repo`
  """
  @spec worktree_add(repo, binary, binary, binary | :undefined) :: {:ok, worktree} | {:error, term}
  def worktree_add(_repo, _name, _path, _ref) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  @doc """
  Prunes a working tree.
  """
  @spec worktree_prune(worktree) :: :ok | {:error, term}
  def worktree_prune(_worktree) do
    raise Code.LoadError, file: nif_path() <> ".so"
  end

  #
  # Helpers
  #

  defp reference_stream_next(iter) do
    case reference_next(iter) do
      {:ok, name, type, shortname, target} ->
        {[{name, type, shortname, target}], iter}
      {:error, :iterover} ->
        {:halt, iter}
    end
  end

  defp revwalk_stream_next(walk) do
    case revwalk_next(walk) do
      {:ok, oid} ->
        {[oid], walk}
      {:error, :iterover} ->
        {:halt, walk}
    end
  end

  defp commit_parent_stream_next({_commit, max, max} = iter), do: {:halt, iter}
  defp commit_parent_stream_next({commit, i, max}) do
    case commit_parent(commit, i) do
      {:ok, oid, parent} -> {[{oid, parent}], {commit, i+1, max}}
    end
  end

  defp tree_stream_next(iter) do
    {tree, i} = iter
    case tree_nth(tree, i) do
      {:ok, mode, type, oid, path} ->
        {[{mode, type, oid, path}], {tree, i+1}}
      {:error, :enomem} ->
        {:halt, iter}
    end
  end

  defp nif_path, do: Path.join(:code.priv_dir(:gitrekt), "geef_nif")
end
