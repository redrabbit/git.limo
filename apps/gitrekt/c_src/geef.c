#include "erl_nif.h"
#include "repository.h"
#include "reference.h"
#include "oid.h"
#include "object.h"
#include "odb.h"
#include "commit.h"
#include "tree.h"
#include "blob.h"
#include "tag.h"
#include "library.h"
#include "revwalk.h"
#include "pathspec.h"
#include "diff.h"
#include "index.h"
#include "signature.h"
#include "revparse.h"
#include "reflog.h"
#include "graph.h"
#include "config.h"
#include "pack.h"
#include "worktree.h"
#include "geef.h"
#include <stdio.h>
#include <string.h>
#include <git2.h>

ErlNifResourceType *geef_repository_type;
ErlNifResourceType *geef_odb_type;
ErlNifResourceType *geef_odb_writepack_type;
ErlNifResourceType *geef_ref_iter_type;
ErlNifResourceType *geef_object_type;
ErlNifResourceType *geef_revwalk_type;
ErlNifResourceType *geef_diff_type;
ErlNifResourceType *geef_index_type;
ErlNifResourceType *geef_config_type;
ErlNifResourceType *geef_pack_type;
ErlNifResourceType *geef_worktree_type;

geef_atoms atoms;

static int load(ErlNifEnv *env, void **priv, ERL_NIF_TERM load_info)
{
	git_libgit2_init();

	geef_repository_type = enif_open_resource_type(env, NULL,
		"repository_type", geef_repository_free, ERL_NIF_RT_CREATE, NULL);

	if (geef_repository_type == NULL)
		return -1;

	geef_odb_type = enif_open_resource_type(env, NULL,
		"odb_type", geef_odb_free, ERL_NIF_RT_CREATE, NULL);

	if (geef_odb_type == NULL)
		return -1;

	geef_odb_writepack_type = enif_open_resource_type(env, NULL,
		"odb_writepack_type", geef_odb_writepack_free, ERL_NIF_RT_CREATE, NULL);

	if (geef_odb_writepack_type == NULL)
		return -1;

	geef_ref_iter_type = enif_open_resource_type(env, NULL,
		"ref_iter_type", geef_ref_iter_free, ERL_NIF_RT_CREATE, NULL);

	if (geef_ref_iter_type == NULL)
		return -1;

	geef_object_type = enif_open_resource_type(env, NULL,
		"object_type", geef_object_free, ERL_NIF_RT_CREATE, NULL);

	if (geef_object_type == NULL)
		return -1;

	geef_revwalk_type = enif_open_resource_type(env, NULL,
		"revwalk_type", geef_revwalk_free, ERL_NIF_RT_CREATE, NULL);

	if (geef_revwalk_type == NULL)
		return -1;

	geef_diff_type = enif_open_resource_type(env, NULL,
		"diff_type", geef_diff_free, ERL_NIF_RT_CREATE, NULL);

	if (geef_diff_type == NULL)
		return -1;

	geef_index_type = enif_open_resource_type(env, NULL,
		"index_type", geef_index_free, ERL_NIF_RT_CREATE, NULL);

	if (geef_index_type == NULL)
		return -1;

	geef_config_type = enif_open_resource_type(env, NULL,
		"config_type", geef_config_free, ERL_NIF_RT_CREATE, NULL);

	if (geef_config_type == NULL)
		return -1;

	geef_pack_type = enif_open_resource_type(env, NULL,
		"pack_type", geef_pack_free, ERL_NIF_RT_CREATE, NULL);

	if (geef_pack_type == NULL)
		return -1;

	geef_worktree_type = enif_open_resource_type(env, NULL,
		"worktree_type", geef_worktree_free, ERL_NIF_RT_CREATE, NULL);

	if (geef_worktree_type == NULL)
		return -1;

	atoms.ok = enif_make_atom(env, "ok");
	atoms.error = enif_make_atom(env, "error");
	atoms.nil = enif_make_atom(env, "nil");
	atoms.true = enif_make_atom(env, "true");
	atoms.false = enif_make_atom(env, "false");
	atoms.repository = enif_make_atom(env, "repository");
	atoms.oid = enif_make_atom(env, "oid");
	atoms.symbolic = enif_make_atom(env, "symbolic");
	atoms.commit = enif_make_atom(env, "commit");
	atoms.tree = enif_make_atom(env, "tree");
	atoms.blob = enif_make_atom(env, "blob");
	atoms.tag = enif_make_atom(env, "tag");
	atoms.format_patch = enif_make_atom(env, "patch");
	atoms.format_patch_header = enif_make_atom(env, "patch_header");
	atoms.format_raw = enif_make_atom(env, "raw");
	atoms.format_name_only = enif_make_atom(env, "name_only");
	atoms.format_name_status = enif_make_atom(env, "name_status");
	atoms.diff_opts_pathspec = enif_make_atom(env, "pathspec");
	atoms.diff_opts_context_lines = enif_make_atom(env, "context_lines");
	atoms.diff_opts_interhunk_lines = enif_make_atom(env, "interhunk_lines");
	atoms.undefined = enif_make_atom(env, "undefined");
	atoms.reflog_entry = enif_make_atom(env, "geef_reflog_entry");
	/* Revwalk */
	atoms.toposort    = enif_make_atom(env, "sort_topo");
	atoms.timesort    = enif_make_atom(env, "sort_time");
	atoms.reversesort = enif_make_atom(env, "sort_reverse");
	atoms.iterover    = enif_make_atom(env, "iterover");
	/* Indexer progress */
	atoms.indexer_total_objects = enif_make_atom(env, "total_objects");
	atoms.indexer_indexed_objects = enif_make_atom(env, "indexed_objects");
	atoms.indexer_received_objects = enif_make_atom(env, "received_objects");
	atoms.indexer_local_objects = enif_make_atom(env, "local_objects");
	atoms.indexer_total_deltas = enif_make_atom(env, "total_deltas");
	atoms.indexer_indexed_deltas = enif_make_atom(env, "indexed_deltas");
	atoms.indexer_received_bytes = enif_make_atom(env, "received_bytes");
	/* Errors */
	atoms.zlib_need_dict = enif_make_atom(env, "zlib_need_dict");
	atoms.zlib_data_error = enif_make_atom(env, "zlib_data_error");
	atoms.zlib_stream_error = enif_make_atom(env, "zlib_stream_error");
	atoms.enomem = enif_make_atom(env, "enomem");
	atoms.eunknown = enif_make_atom(env, "eunknown");
	atoms.estruct = enif_make_atom(env, "__struct__");
	atoms.emod = enif_make_atom(env, "Elixir.GitRekt.GitError");
	atoms.ex = enif_make_atom(env, "__exception__");
	atoms.emsg = enif_make_atom(env, "message");
	atoms.ecode = enif_make_atom(env, "code");

	return 0;
}

int upgrade(ErlNifEnv* env, void** priv_data, void** old_priv_data, ERL_NIF_TERM load_info)
{
	return 0;
}

static void unload(ErlNifEnv* env, void* priv_data)
{
	git_libgit2_shutdown();
}

ERL_NIF_TERM
geef_error(ErlNifEnv *env)
{
	const git_error *error;
	ErlNifBinary bin;
	size_t len;

	error = giterr_last();

	if (!error)
		return enif_make_tuple2(env, atoms.error, atoms.eunknown);

	if (error->klass == GITERR_NOMEMORY)
		return geef_oom(env);

	if (!error->message)
		return enif_make_tuple2(env, atoms.error, atoms.eunknown);

	len = strlen(error->message);
	if (!enif_alloc_binary(len, &bin))
		return geef_oom(env);

	memcpy(bin.data, error->message, len);

	return enif_make_tuple2(env, atoms.error, enif_make_binary(env, &bin));
}

ERL_NIF_TERM
geef_error_struct(ErlNifEnv *env, int code)
{
	ERL_NIF_TERM struct_term;
	ERL_NIF_TERM keys[] = {
		atoms.estruct,
		atoms.ex,
		atoms.emsg,
		atoms.ecode
	};

	const git_error *error;
	ErlNifBinary bin;
	size_t len;

	error = giterr_last();

	if (!error)
		return enif_make_tuple2(env, atoms.error, atoms.eunknown);

	if (error->klass == GITERR_NOMEMORY)
		return geef_oom(env);

	if (!error->message)
		return enif_make_tuple2(env, atoms.error, atoms.eunknown);

	len = strlen(error->message);
	if (!enif_alloc_binary(len, &bin))
		return geef_oom(env);

	memcpy(bin.data, error->message, len);
	ERL_NIF_TERM values[] = {
		atoms.emod,
		atoms.true,
		enif_make_binary(env, &bin),
		enif_make_int(env, code)
	};

	error = enif_make_map_from_arrays(env, keys, values, 4, &struct_term);
	if (error < 0)
		return geef_error_struct(env, error);

	return enif_make_tuple2(env, atoms.error, struct_term);
}

ERL_NIF_TERM
geef_oom(ErlNifEnv *env)
{
	return enif_make_tuple2(env, atoms.error, atoms.enomem);
}

git_strarray git_strarray_from_list(ErlNifEnv *env, ERL_NIF_TERM list)
{
	ErlNifBinary bin;
	ERL_NIF_TERM head, tail;
	unsigned int i, size;
	git_strarray array = { NULL, 0 };

	if (!enif_get_list_length(env, list, &size))
		return array;

	array.count = size;
	array.strings = malloc(sizeof(char*) * size);

	tail = list;
	for(i = 0; i < size; i++) {
		if (!enif_get_list_cell(env, tail, &head, &tail))
			return array;

		if (!enif_inspect_binary(env, head, &bin))
			return array;

		array.strings[i] = memcpy(malloc((bin.size+1) * sizeof(char)), bin.data, bin.size+1);
		array.strings[i][bin.size] = '\0';
	}

	return array;
}

int geef_terminate_binary(ErlNifBinary *bin)
{
	if (!enif_realloc_binary(bin, bin->size + 1))
		return 0;

	bin->data[bin->size - 1] = '\0';

	return 1;
}

int geef_string_to_bin(ErlNifBinary *bin, const char *str)
{
	size_t len;

	if (str == NULL)
		len = 0;
	else
		len = strlen(str);

	if (!enif_alloc_binary(len, bin))
		return -1;

	memcpy(bin->data, str, len);
	return 0;
}

static ErlNifFunc geef_funcs[] =
{
	{"repository_init", 2, geef_repository_init, 0},
	{"repository_open", 1, geef_repository_open, 0},
	{"repository_discover", 1, geef_repository_discover, 0},
	{"repository_bare?", 1, geef_repository_is_bare, 0},
	{"repository_empty?", 1, geef_repository_is_empty, 0},
	{"repository_get_path", 1, geef_repository_path, 0},
	{"repository_get_workdir", 1, geef_repository_workdir, 0},
	{"repository_get_odb", 1, geef_repository_odb, 0},
	{"repository_get_index", 1, geef_repository_index, 0},
	{"repository_get_config", 1, geef_repository_config, 0},
        {"repository_set_head", 2, geef_repository_set_head, 0},
	{"odb_object_hash", 2, geef_odb_hash, 0},
	{"odb_object_exists?", 2, geef_odb_exists, 0},
	{"odb_read", 2, geef_odb_read, 0},
	{"odb_write", 3, geef_odb_write, 0},
	{"odb_write_pack", 2, geef_odb_write_pack, 0},
	{"odb_get_writepack", 1, geef_odb_get_writepack, 0},
	{"odb_writepack_append", 3, geef_odb_writepack_append, 0},
	{"odb_writepack_commit", 2, geef_odb_writepack_commit, 0},
	{"reference_list", 1, geef_reference_list, 0},
	{"reference_peel", 3, geef_reference_peel, 0},
	{"reference_to_id", 2, geef_reference_to_id, 0},
	{"reference_glob", 2, geef_reference_glob, 0},
	{"reference_lookup", 2, geef_reference_lookup, 0},
	{"reference_iterator", 2, geef_reference_iterator, 0},
	{"reference_next", 1, geef_reference_next, 0},
	{"reference_resolve", 2, geef_reference_resolve, 0},
	{"reference_create", 5, geef_reference_create, 0},
	{"reference_delete", 2, geef_reference_delete, 0},
	{"reference_dwim", 2,   geef_reference_dwim, 0},
	{"reference_log?", 2, geef_reference_has_log, 0},
	{"reflog_count", 2, geef_reflog_count, 0},
	{"reflog_read", 2, geef_reflog_read, 0},
	{"reflog_delete", 2, geef_reflog_delete, 0},
	{"graph_ahead_behind", 3, geef_graph_ahead_behind, 0},
	{"oid_fmt", 1, geef_oid_fmt, 0},
	{"oid_parse", 1, geef_oid_parse, 0},
	{"object_repository", 1, geef_object_repository, 0},
	{"object_lookup", 2, geef_object_lookup, 0},
	{"object_id", 1, geef_object_id, 0},
	{"object_zlib_inflate", 2, geef_object_zlib_inflate, 0},
	{"commit_parent", 2, geef_commit_parent, 0},
	{"commit_parent_count", 1, geef_commit_parent_count, 0},
	{"commit_tree", 1, geef_commit_tree, 0},
	{"commit_tree_id", 1, geef_commit_tree_id, 0},
	{"commit_create",  8, geef_commit_create, 0},
	{"commit_message", 1, geef_commit_message, 0},
	{"commit_author", 1, geef_commit_author, 0},
	{"commit_committer", 1, geef_commit_committer, 0},
	{"commit_time", 1, geef_commit_time, 0},
	{"commit_raw_header", 1, geef_commit_raw_header, 0},
	{"commit_header", 2, geef_commit_header, 0},
	{"tree_bypath", 2, geef_tree_bypath, 0},
	{"tree_byid", 2, geef_tree_byid, 0},
	{"tree_nth", 2, geef_tree_nth, 0},
	{"tree_count", 1, geef_tree_count, 0},
	{"blob_size", 1, geef_blob_size, 0},
	{"blob_content", 1, geef_blob_content, 0},
	{"tag_list", 1, geef_tag_list, 0},
	{"tag_peel", 1, geef_tag_peel, 0},
	{"tag_name", 1, geef_tag_name, 0},
	{"tag_message", 1, geef_tag_message, 0},
	{"tag_author", 1, geef_tag_author, 0},
	{"library_version", 0, geef_library_version, 0},
	{"revwalk_new",  1, geef_revwalk_new, 0},
	{"revwalk_push", 3, geef_revwalk_push, 0},
	{"revwalk_next", 1, geef_revwalk_next, 0},
	{"revwalk_sorting", 2, geef_revwalk_sorting, 0},
	{"revwalk_simplify_first_parent", 1, geef_revwalk_simplify_first_parent, 0},
	{"revwalk_reset", 1,   geef_revwalk_reset, 0},
	{"revwalk_repository", 1, geef_revwalk_repository, 0},
	{"revwalk_pack", 1, geef_revwalk_pack, 0},
	{"pathspec_match_tree", 2, geef_pathspec_match_tree, 0},
	{"diff_tree", 4, geef_diff_tree, 0},
	{"diff_stats", 1, geef_diff_stats, 0},
	{"diff_delta_count", 1, geef_diff_delta_count, 0},
	{"diff_deltas", 1, geef_diff_deltas, 0},
	{"diff_format", 2, geef_diff_format, 0},
	{"index_new", 0, geef_index_new, 0},
	{"index_read_tree", 2, geef_index_read_tree, 0},
	{"index_write", 1, geef_index_write, 0},
	{"index_write_tree", 1, geef_index_write_tree, 0},
	{"index_write_tree", 2, geef_index_write_tree, 0},
	{"index_add", 2, geef_index_add, 0},
	{"index_remove", 3, geef_index_remove, 0},
	{"index_remove_dir", 3, geef_index_remove_dir, 0},
	{"index_count", 1, geef_index_count, 0},
	{"index_bypath", 3, geef_index_get, 0},
	{"index_nth", 2, geef_index_nth, 0},
	{"index_clear", 1, geef_index_clear, 0},
	{"signature_default", 1, geef_signature_default, 0},
	{"revparse_single", 2, geef_revparse_single, 0},
	{"revparse_ext", 2, geef_revparse_ext, 0},
	{"config_set_bool", 3, geef_config_set_bool, 0},
	{"config_get_bool", 2, geef_config_get_bool, 0},
	{"config_set_string", 3, geef_config_set_string, 0},
	{"config_get_string", 2, geef_config_get_string, 0},
	{"config_open", 1, geef_config_open, 0},
	{"pack_new", 1, geef_pack_new, 0},
	{"pack_insert_commit", 2, geef_pack_insert_commit, 0},
	{"pack_insert_walk", 2, geef_pack_insert_walk, 0},
	{"pack_data", 1, geef_pack_data, 0},
	{"worktree_add", 4, geef_worktree_add, 0},
	{"worktree_prune", 1, geef_worktree_prune, 0},
};

ERL_NIF_INIT(Elixir.GitRekt.Git, geef_funcs, load, NULL, upgrade, unload)
