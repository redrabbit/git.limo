defmodule GitRekt.Geef do
  @moduledoc """
  Erlang NIF that exposes some of *libgit2*'s library functions.
  """

  require Logger

  @type handle :: reference

  @nif_path Path.join(:code.priv_dir(:gitrekt), "geef_nif")

  @on_load :load_nif

  @doc false
  def load_nif do
    case :erlang.load_nif(@nif_path, 0) do
      :ok -> :ok
      {:error, {:load_failed, error}} -> Logger.error error
    end
  end

  @spec repository_open(binary) :: {:ok, handle} | {:error, term}
  def repository_open(_path) do
    raise "geef_nif.so not loaded"
  end

  @spec repository_is_bare(handle) :: boolean
  def repository_is_bare(_handle) do
    raise "geef_nif.so not loaded"
  end

  @spec repository_get_path(handle) :: binary
  def repository_get_path(_handle) do
    raise "geef_nif.so not loaded"
  end

  @spec repository_get_workdir(handle) :: binary
  def repository_get_workdir(_handle) do
      raise "geef_nif.so not loaded"
    end

  @spec repository_get_odb(handle) :: term # TODO
  def repository_get_odb(_handle) do
      raise "geef_nif.so not loaded"
    end

  @spec repository_get_config(handle) :: {:ok, term} | {:error, term}
  def repository_get_config(_handle) do
    raise "geef_nif.so not loaded"
  end

  @spec repository_init(binary, boolean) :: handle
  def repository_init(_path, _bare) do
    raise "geef_nif.so not loaded"
  end

  @spec repository_discover(binary) :: {:ok, binary} | :error
  def repository_discover(_path) do
    raise "geef_nif.so not loaded"
  end

  def reference_list(_Repo) do
    raise "geef_nif.so not loaded"
  end

  #spec reference_create(term(), iolist(), geef_ref:type(), iolist() | geef_oid:oid(), boolean()) -> ok | {error, term()}.
  def reference_create(_Repo, _Refname, _Type, _Target, _Force) do
    raise "geef_nif.so not loaded"
  end

  def reference_to_id(_Repo, _Refname) do
    raise "geef_nif.so not loaded"
  end

  def reference_glob(_Repo, _Glob) do
    raise "geef_nif.so not loaded"
  end

  #spec reference_lookup(term(), binary() | iolist()) -> {ok, geef_ref:type(), binary()} | {error, term()}.
  def reference_lookup(_RepoHandle, _Refname) do
    raise "geef_nif.so not loaded"
  end

  #spec reference_iterator(term(), iolist() | undefined) -> {ok, geef_ref:iterator()} | {error, term()}.
  def reference_iterator(_Repo, _Regexp) do
    raise "geef_nif.so not loaded"
  end

  #spec reference_next(geef_ref:iterator()) -> {ok, binary(), geef_ref:type(), binary()} | {error, iterover | term()}.
  def reference_next(_Handle) do
    raise "geef_nif.so not loaded"
  end

  #spec reference_resolve(term(), binary()) -> {ok, binary(), binary()} | {error, term()}.
  def reference_resolve(_RepoHandle, _Name) do
    raise "geef_nif.so not loaded"
  end

  def reference_dwim(_Handle, _Name) do
    raise "geef_nif.so not loaded"
  end

  #spec reference_has_log(term(), iolist()) -> {ok, boolean()} | {error, term()}.
  def reference_has_log(_Handle, _Name) do
    raise "geef_nif.so not loaded"
  end

  #spec reflog_read(term(), iolist()) -> {ok, binary(), binary(), non_neg_integer(), non_neg_integer()} | {error, term()}.
  def reflog_read(_Handle, _Name) do
    raise "geef_nif.so not loaded"
  end

  #spec reflog_delete(term(), iolist()) -> ok | {error, term()}.
  def reflog_delete(_Handle, _Name) do
    raise "geef_nif.so not loaded"
  end

  def odb_object_exists(_one, _two) do
    raise "geef_nif.so not loaded"
  end

  #spec odb_write(term(), iolist(), atom()) -> term().
  def odb_write(_Handle, _Contents, _Type) do
    raise "geef_nif.so not loaded"
  end

  def oid_fmt(_Oid) do
    raise "geef_nif.so not loaded"
  end

  def oid_parse(_Sha) do
    raise "geef_nif.so not loaded"
  end

  def object_lookup(_Repo, _Oid) do
    raise "geef_nif.so not loaded"
  end

  def object_id(_Handle) do
    raise "geef_nif.so not loaded"
  end

  #spec commit_tree_id(term) -> binary().
  def commit_tree_id(_Handle) do
    raise "geef_nif.so not loaded"
  end

  #spec commit_tree(term) -> term().
  def commit_tree(_Handle) do
    raise "geef_nif.so not loaded"
  end


  def commit_create(_RepoHandle, _Ref, _Author, _Committer, _Encoding, _Message, _Tree, _Parents) do
    raise "geef_nif.so not loaded"
  end

  #spec commit_message(term) -> {ok, binary()} | {error, term()}.
  def commit_message(_CommitHandle) do
    raise "geef_nif.so not loaded"
  end

  #spec tree_bypath(term, iolist()) -> term().
  def tree_bypath(_TreeHandle, _Path) do
    raise "geef_nif.so not loaded"
  end

  #spec tree_nth(term, non_neg_integer()) -> term().
  def tree_nth(_TreeHandle, _Nth) do
    raise "geef_nif.so not loaded"
  end

  #spec tree_count(term) -> non_neg_integer().
  def tree_count(_Treehandle) do
    raise "geef_nif.so not loaded"
  end

  #spec blob_size(term) -> {ok, integer()} | error.
  def blob_size(_ObjHandle) do
    raise "geef_nif.so not loaded"
  end

  #spec blob_content(term) -> {ok, binary()} | error.
  def blob_content(_ObjHandle) do
    raise "geef_nif.so not loaded"
  end

  #spec tag_peel(term()) -> {ok, atom(), binary(), term()} | {error, term()}.
  def tag_peel(_Tag) do
    raise "geef_nif.so not loaded"
  end

  #spec library_version() -> {integer, integer, integer}.
  def library_version() do
    raise "geef_nif.so not loaded"
  end

  def revwalk_new(_Repo) do
    raise "geef_nif.so not loaded"
  end

  def revwalk_push(_Walk, _Id, _Hide) do
    raise "geef_nif.so not loaded"
  end

  def revwalk_next(_Walk) do
    raise "geef_nif.so not loaded"
  end

  def revwalk_sorting(_Walk, _Sort) do
    raise "geef_nif.so not loaded"
  end

  def revwalk_simplify_first_parent(_Walk) do
    raise "geef_nif.so not loaded"
  end

  def revwalk_reset(_Walk) do
    raise "geef_nif.so not loaded"
  end

  def index_new() do
    raise "geef_nif.so not loaded"
  end

  def index_write(_Handle) do
    raise "geef_nif.so not loaded"
  end

  def index_write_tree(_Handle) do
    raise "geef_nif.so not loaded"
  end

  def index_write_tree(_Handle, _RepoHandle) do
    raise "geef_nif.so not loaded"
  end

  def index_read_tree(_Handle, _TreeHandle) do
    raise "geef_nif.so not loaded"
  end

  #spec index_count(term()) -> non_neg_integer().
  def index_count(_Handle) do
    raise "geef_nif.so not loaded"
  end

  #spec index_nth(term(), non_neg_integer()) -> {ok, geef_index:entry()} | {error, term()}.
  def index_nth(_Handle, _Nth) do
    raise "geef_nif.so not loaded"
  end

  #spec index_get(term(), iolist(), non_neg_integer()) -> {ok, geef_index:entry()} | {error, term()}.
  def index_get(_Handle, _Path, _Stage) do
    raise "geef_nif.so not loaded"
  end

  def index_add(_Handle, _Entry) do
    raise "geef_nif.so not loaded"
  end

  def index_clear(_Handle) do
    raise "geef_nif.so not loaded"
  end

  #spec signature_default(term()) -> {ok, binary(), binary(), non_neg_integer(), non_neg_integer()} | {error, term()}.
  def signature_default(_Repo) do
    raise "geef_nif.so not loaded"
  end

  def signature_new(_Name, _Email) do
    raise "geef_nif.so not loaded"
  end

  def signature_new(_Name, _Email, _Time) do
    raise "geef_nif.so not loaded"
  end

  #spec revparse_single(term(), iolist()) -> {ok, term(), atom(), geef_oid:oid()} | {error, term()}.
  def revparse_single(_Handle, _Str) do
    raise "geef_nif.so not loaded"
  end

  #spec config_set_bool(term(), iolist(), boolean()) -> ok | {error, term()}.
  def config_set_bool(_Handle, _Name, _Val) do
    raise "geef_nif.so not loaded"
  end

  #spec config_get_bool(term(), iolist()) -> {ok, boolean()} | {error, term()}.
  def config_get_bool(_Handle, _Name) do
    raise "geef_nif.so not loaded"
  end


  #spec config_set_string(term(), iolist(), iolist()) -> ok | {error, term()}.
  def config_set_string(_Handle, _Name, _Val) do
    raise "geef_nif.so not loaded"
  end


  #spec config_get_string(term(), iolist()) -> {ok, binary()} | {error, term()}.
  def config_get_string(_Handle, _Name) do
    raise "geef_nif.so not loaded"
  end

  #spec config_open(iolist()) -> {ok, term()} | {error, term()}.
  def config_open(_Path) do
    raise "geef_nif.so not loaded"
  end
end
