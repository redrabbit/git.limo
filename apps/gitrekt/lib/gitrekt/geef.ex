defmodule GitRekt.Geef do
  @moduledoc """
  Erlang NIF that exposes some of *libgit2*'s library functions.
  """

  require Logger

  @type repo :: reference
  @type config :: reference

  @nif_path Path.join(:code.priv_dir(:gitrekt), "geef_nif")
  @nif_path_lib @nif_path <> ".so"

  @on_load :load_nif

  @doc false
  def load_nif do
    case :erlang.load_nif(@nif_path, 0) do
      :ok -> :ok
      {:error, {:load_failed, error}} -> Logger.error error
    end
  end

  @doc """
  Returns a repository handle for the `path`.
  """
  @spec repository_open(binary) :: {:ok, repo} | {:error, term}
  def repository_open(_path) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc """
  Returns `true` if `repo` is bare; elsewhise returns `false`.
  """
  @spec repository_bare?(repo) :: boolean
  def repository_bare?(_repo) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc """
  Returns the absolute path for the given `repo`.
  """
  @spec repository_get_path(repo) :: binary
  def repository_get_path(_repo) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc """
  Returns the normalized path to the working directory for the given `repo`.
  """
  @spec repository_get_workdir(repo) :: binary
  def repository_get_workdir(_repo) do
      raise Code.LoadError, file: @nif_path_lib
    end

  @doc false
  def repository_get_odb(_repo) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc """
  Returns the config for the given `repo`.
  """
  @spec repository_get_config(repo) :: {:ok, config} | {:error, term}
  def repository_get_config(_repo) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc """
  Initializes a new repository at the given `path`.
  """
  @spec repository_init(binary, boolean) :: repo
  def repository_init(_path, _bare) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc """
  Looks for a repository and returns its path.
  """
  @spec repository_discover(binary) :: {:ok, binary} | :error
  def repository_discover(_path) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc """
  Returns all references for the given `repo`.
  """
  @spec reference_list(repo) :: [binary]
  def reference_list(_repo) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc """
  Creates a new reference name which points to an object or to an other reference.
  """
  @spec reference_create(repo, binary, :geef_ref.type, binary | :geef_oid.oid, boolean) :: :ok | {:error, term}
  def reference_create(_repo, _ref_name, _type, _target, _force) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc """
  Looks for a reference by `ref_name` and returns its id.
  """
  @spec reference_to_id(repo, binary) :: {:ok, binary} | {:error, term}
  def reference_to_id(_repo, _ref_name) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc """
  Similar to `reference_resolve/2` but allows glob patterns.
  """
  @spec reference_glob(repo, binary) :: {:ok, binary, binary} | {:error, term}
  def reference_glob(_repo, _glob) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc """
  Looks for a reference by `ref_name`.
  """
  @spec reference_lookup(repo, binary) :: {:ok, :geef_ref.type, binary} | {:error, term}
  def reference_lookup(_repo, _ref_name) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc """
  Returns an iterator for the references that match the specific `glob`.
  """
  @spec reference_iterator(repo, binary | :undefined) :: {:ok, :geef_ref.iterator} | {:error, term}
  def reference_iterator(_repo, _glob) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc """
  Returns the next reference.
  """
  @spec reference_next(:geef_ref.iterator) :: {:ok, binary, :geef_ref.type, binary} | {:error, :iterover | term}
  def reference_next(_iter) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc """
  Resolves the reference with the given `name`.
  """
  @spec reference_resolve(repo, binary) :: {:ok, binary, binary} | {:error, term}
  def reference_resolve(_repo, _name) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc """
  Looks for a reference by DWIMing its `short_name`.
  """
  @spec reference_dwim(repo, binary) :: {:ok, :geef_ref.type, :geef_ref.oid, binary} | {:error, term}
  def reference_dwim(_repo, _short_name) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc """
  Returns `true` if a reflog exists for the given reference `name`.
  """
  @spec reference_log?(repo, binary) :: {:ok, boolean} | {:error, term}
  def reference_log?(_repo, _name) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc false
  #spec reflog_read(term(), iolist()) -> {ok, binary(), binary(), non_neg_integer(), non_neg_integer()} | {error, term()}.
  def reflog_read(_Handle, _Name) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc false
  #spec reflog_delete(term(), iolist()) -> ok | {error, term()}.
  def reflog_delete(_Handle, _Name) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc false
  def odb_object_exists(_one, _two) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc false
  #spec odb_write(term(), iolist(), atom()) -> term().
  def odb_write(_Handle, _Contents, _Type) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc false
  def oid_fmt(_Oid) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc false
  def oid_parse(_Sha) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc false
  def object_lookup(_Repo, _Oid) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc false
  def object_id(_Handle) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc false
  #spec commit_tree_id(term) -> binary().
  def commit_tree_id(_Handle) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc false
  #spec commit_tree(term) -> term().
  def commit_tree(_Handle) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc false
  def commit_create(_RepoHandle, _Ref, _Author, _Committer, _Encoding, _Message, _Tree, _Parents) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc false
  #spec commit_message(term) -> {ok, binary()} | {error, term()}.
  def commit_message(_CommitHandle) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc false
  #spec tree_bypath(term, iolist()) -> term().
  def tree_bypath(_TreeHandle, _Path) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc false
  #spec tree_nth(term, non_neg_integer()) -> term().
  def tree_nth(_TreeHandle, _Nth) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc false
  #spec tree_count(term) -> non_neg_integer().
  def tree_count(_TreeHande) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc false
  #spec blob_size(term) -> {ok, integer()} | error.
  def blob_size(_ObjHandle) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc false
  #spec blob_content(term) -> {ok, binary()} | error.
  def blob_content(_ObjHandle) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc false
  #spec tag_peel(term()) -> {ok, atom(), binary(), term()} | {error, term()}.
  def tag_peel(_Tag) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc """
  Returns the *libgit2* library version.
  """
  @spec library_version() :: {integer, integer, integer}
  def library_version() do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc false
  def revwalk_new(_Repo) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc false
  def revwalk_push(_Walk, _Id, _Hide) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc false
  def revwalk_next(_Walk) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc false
  def revwalk_sorting(_Walk, _Sort) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc false
  def revwalk_simplify_first_parent(_Walk) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc false
  def revwalk_reset(_Walk) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc false
  def index_new() do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc false
  def index_write(_Handle) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc false
  def index_write_tree(_Handle) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc false
  def index_write_tree(_Handle, _RepoHandle) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc false
  def index_read_tree(_Handle, _TreeHandle) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc false
  #spec index_count(term()) -> non_neg_integer().
  def index_count(_Handle) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc false
  #spec index_nth(term(), non_neg_integer()) -> {ok, geef_index:entry()} | {error, term()}.
  def index_nth(_Handle, _Nth) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc false
  #spec index_get(term(), iolist(), non_neg_integer()) -> {ok, geef_index:entry()} | {error, term()}.
  def index_get(_Handle, _Path, _Stage) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc false
  def index_add(_Handle, _Entry) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc false
  def index_clear(_Handle) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc false
  #spec signature_default(term()) -> {ok, binary(), binary(), non_neg_integer(), non_neg_integer()} | {error, term()}.
  def signature_default(_Repo) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc false
  def signature_new(_Name, _Email) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc false
  def signature_new(_Name, _Email, _Time) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc false
  #spec revparse_single(term(), iolist()) -> {ok, term(), atom(), geef_oid:oid()} | {error, term()}.
  def revparse_single(_Handle, _Str) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc """
  Sets the `config` entry with the given `name` to `val`.
  """
  @spec config_set_bool(config, binary, boolean) :: :ok | {:error, term}
  def config_set_bool(_config, _name, _val) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc """
  Returns the value of the `config` entry with the given `name`.
  """
  @spec config_get_bool(config, binary) :: {:ok, boolean} | {:error, term}
  def config_get_bool(_config, _name) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc """
  Sets the `config` entry with the given `name` to `val`.
  """
  @spec config_set_string(config, binary, binary) :: :ok | {:error, term}
  def config_set_string(_config, _name, _val) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc """
  Returns the value of the `config` entry with the given `name`.
  """
  @spec config_get_string(config, binary) :: {:ok, binary} | {:error, term}
  def config_get_string(_config, _name) do
    raise Code.LoadError, file: @nif_path_lib
  end

  @doc """
  Returns a config handle for the given `path`.
  """
  @spec config_open(binary) :: {:ok, config} | {:error, term}
  def config_open(_path) do
    raise Code.LoadError, file: @nif_path_lib
  end
end
