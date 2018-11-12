#include "erl_nif.h"
#include "repository.h"
#include "reference.h"
#include "oid.h"
#include "object.h"
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
#include "config.h"
#include "pack.h"
#include "geef.h"
#include <stdio.h>
#include <string.h>
#include <git2.h>

ErlNifResourceType *geef_repository_type;
ErlNifResourceType *geef_odb_type;
ErlNifResourceType *geef_ref_iter_type;
ErlNifResourceType *geef_object_type;
ErlNifResourceType *geef_revwalk_type;
ErlNifResourceType *geef_diff_type;
ErlNifResourceType *geef_index_type;
ErlNifResourceType *geef_config_type;
ErlNifResourceType *geef_pack_type;

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

	geef_ref_iter_type = enif_open_resource_type(env, NULL,
		    "ref_iter_type", geef_ref_iter_free, ERL_NIF_RT_CREATE, NULL);

	if (geef_ref_iter_type == NULL)
		return -1;

	geef_object_type = enif_open_resource_type(env, NULL,
						     "object_type", geef_object_free, ERL_NIF_RT_CREATE, NULL);

	geef_revwalk_type = enif_open_resource_type(env, NULL,
		  "revwalk_type", geef_revwalk_free, ERL_NIF_RT_CREATE, NULL);

	geef_diff_type = enif_open_resource_type(env, NULL,
		  "diff_type", geef_diff_free, ERL_NIF_RT_CREATE, NULL);

	geef_index_type = enif_open_resource_type(env, NULL,
		  "index_type", geef_index_free, ERL_NIF_RT_CREATE, NULL);

	geef_config_type = enif_open_resource_type(env, NULL,
		  "config_type", geef_config_free, ERL_NIF_RT_CREATE, NULL);

	geef_pack_type = enif_open_resource_type(env, NULL,
		  "pack_type", geef_pack_free, ERL_NIF_RT_CREATE, NULL);


	if (geef_repository_type == NULL)
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
	/* Errors */
	atoms.enomem = enif_make_atom(env, "enomem");
	atoms.eunknown = enif_make_atom(env, "eunknown");

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
geef_oom(ErlNifEnv *env)
{
	return enif_make_tuple2(env, atoms.error, atoms.enomem);
}

git_strarray git_strarray_from_list(ErlNifEnv *env, ERL_NIF_TERM list)
{
	ErlNifBinary bin;
	ERL_NIF_TERM head, tail;
	unsigned int i, size;
	git_strarray array;

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
	{"repository_init", 2, geef_repository_init},
	{"repository_open", 1, geef_repository_open},
	{"repository_discover", 1, geef_repository_discover},
	{"repository_bare?", 1, geef_repository_is_bare},
	{"repository_empty?", 1, geef_repository_is_empty},
	{"repository_get_path", 1, geef_repository_path},
	{"repository_get_workdir", 1, geef_repository_workdir},
	{"repository_get_odb", 1, geef_repository_odb},
	{"repository_get_config", 1, geef_repository_config},
	{"odb_object_exists?", 2, geef_odb_exists},
    {"odb_read", 2, geef_odb_read},
	{"odb_write", 3, geef_odb_write},
	{"reference_list", 1, geef_reference_list},
	{"reference_peel", 3, geef_reference_peel},
	{"reference_to_id", 2, geef_reference_to_id},
	{"reference_glob", 2, geef_reference_glob},
	{"reference_lookup", 2, geef_reference_lookup},
	{"reference_iterator", 2, geef_reference_iterator},
	{"reference_next",     1, geef_reference_next},
	{"reference_resolve", 2, geef_reference_resolve},
	{"reference_create", 5, geef_reference_create},
	{"reference_delete", 2, geef_reference_delete},
	{"reference_dwim", 2,   geef_reference_dwim},
	{"reference_log?", 2, geef_reference_has_log},
	{"reflog_count",       2, geef_reflog_count},
	{"reflog_read",       2, geef_reflog_read},
	{"reflog_delete",     2, geef_reflog_delete},
	{"oid_fmt", 1, geef_oid_fmt},
	{"oid_parse", 1, geef_oid_parse},
	{"object_repository", 1, geef_object_repository},
	{"object_lookup", 2, geef_object_lookup},
	{"object_id", 1, geef_object_id},
	{"object_zlib_inflate", 1, geef_object_zlib_inflate},
	{"commit_parent", 2, geef_commit_parent},
	{"commit_parent_count", 1, geef_commit_parent_count},
	{"commit_tree", 1, geef_commit_tree},
	{"commit_tree_id", 1, geef_commit_tree_id},
	{"commit_create",  8, geef_commit_create},
	{"commit_message", 1, geef_commit_message},
	{"commit_author", 1, geef_commit_author},
	{"commit_time", 1, geef_commit_time},
	{"tree_bypath", 2, geef_tree_bypath},
	{"tree_byid", 2, geef_tree_byid},
	{"tree_nth",     2, geef_tree_nth},
	{"tree_count",   1, geef_tree_count},
	{"blob_size", 1, geef_blob_size},
	{"blob_content", 1, geef_blob_content},
	{"tag_list", 1, geef_tag_list},
	{"tag_peel", 1, geef_tag_peel},
	{"tag_name", 1, geef_tag_name},
	{"tag_message", 1, geef_tag_message},
	{"tag_author", 1, geef_tag_author},
	{"library_version", 0, geef_library_version},
	{"revwalk_new",  1,    geef_revwalk_new},
	{"revwalk_push", 3,    geef_revwalk_push},
	{"revwalk_next", 1,    geef_revwalk_next},
	{"revwalk_sorting", 2, geef_revwalk_sorting},
    {"revwalk_simplify_first_parent", 1, geef_revwalk_simplify_first_parent},
	{"revwalk_reset", 1,   geef_revwalk_reset},
	{"revwalk_repository", 1, geef_revwalk_repository},
	{"revwalk_pack", 1, geef_revwalk_pack},
	{"pathspec_match_tree", 2, geef_pathspec_match_tree},
	{"diff_tree",   4, geef_diff_tree},
	{"diff_stats",  1, geef_diff_stats},
	{"diff_delta_count", 1, geef_diff_delta_count},
	{"diff_deltas", 1, geef_diff_deltas},
	{"diff_format", 2, geef_diff_format},
	{"index_new",   0, geef_index_new},
	{"index_write", 1, geef_index_write},
	{"index_write_tree", 1, geef_index_write_tree},
	{"index_write_tree", 2, geef_index_write_tree},
	{"index_add",        2, geef_index_add},
	{"index_count",      1, geef_index_count},
	{"index_bypath",     3, geef_index_get},
	{"index_nth",        2, geef_index_nth},
	{"index_clear",      1, geef_index_clear},
	{"index_read_tree",  2, geef_index_read_tree},
	{"signature_default", 1, geef_signature_default},
	{"revparse_single", 2, geef_revparse_single},
	{"revparse_ext", 2, geef_revparse_ext},
	{"config_set_bool", 3, geef_config_set_bool},
	{"config_get_bool", 2, geef_config_get_bool},
	{"config_set_string", 3, geef_config_set_string},
	{"config_get_string", 2, geef_config_get_string},
	{"config_open",     1, geef_config_open},
	{"pack_new",    1, geef_pack_new},
	{"pack_insert_commit", 2, geef_pack_insert_commit},
	{"pack_insert_walk", 2, geef_pack_insert_walk},
	{"pack_data",   1, geef_pack_data},
};

ERL_NIF_INIT(Elixir.GitRekt.Git, geef_funcs, load, NULL, upgrade, unload)
